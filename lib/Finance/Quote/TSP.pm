#!/usr/bin/perl -w
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@cpan.org>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#    Copyright (C) 2001, Rob Sessink <rob_ses@users.sourceforge.net>
#    Copyright (C) 2004, Frank Mori Hess <fmhess@users.sourceforge.net>
#                        Trent Piepho <xyzzy@spekeasy.org>
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
#    02110-1301, USA
#
#
# This code is derived from version 0.9 of the AEX.pm module.

require 5.005;

use strict;

package Finance::Quote::TSP;

use vars qw( $TSP_URL $TSP_MAIN_URL );

use LWP::UserAgent;
use HTTP::Request::Common;
use POSIX;

# VERSION

# URLs of where to obtain information

$TSP_URL      = 'https://secure.tsp.gov/components/CORS/getSharePricesRaw.html';
$TSP_MAIN_URL = 'http://www.tsp.gov';

sub methods { return (tsp => \&tsp) }

{
  my @labels = qw/name date isodate currency close/;
  sub labels { return (tsp => \@labels); }
}

sub format_name {
  my $name = shift;
  $name =~ s/ //g;
  $name = lc($name);

  return $1 if $name =~ /^(.)fund$/;
  return $name;
}

# ==============================================================================
sub tsp {
  my $quoter = shift;
  my @symbols = @_;

  return unless @symbols;

  my %info;

  # Ask for the last 7 days
  my $startdate = strftime("%Y%m%d", localtime (time - 7*24*3600));
  my $enddate   = strftime("%Y%m%d", localtime time);

  my $ua = $quoter->user_agent;
  my $reply = $ua->request(GET "$TSP_URL?startdate=$startdate;enddate=$enddate;Lfunds=1;InvFunds=1");
  return unless ($reply->is_success);

  my @line = split(/\n/, $reply->content);

  return unless (@line > 1);

  my @header = split(/,/, $line[0]);
  my %column = map { format_name($header[$_]) => $_ } 0 .. $#header;
  my @latest = split(/,/, $line[-1]);

  foreach (@symbols) {
    my $symbol = lc $_;

    if(exists $column{$symbol}) {
      $info{$_, 'success'} = 1;
      $quoter->store_date(\%info, $_, {usdate => $latest[$column{'date'}]});
      ($info{$_, 'last'} = $latest[$column{$symbol}]) =~ s/[^0-9]*([0-9.,]+).*/$1/s;
      $info{$_, 'currency'} = 'USD';
      $info{$_, 'method'} = 'tsp';
      $info{$_, 'source'} = $TSP_MAIN_URL;
      $info{$_, 'symbol'} = $_;
    }
    else {
      $info{$_, 'success'} = 0;
      $info{$_, 'errormsg'} = "Fund not found";
    }
  }

  return %info if wantarray;
  return \%info;
}
1;

=head1 NAME

Finance::Quote::TSP - Obtain fund prices for US Federal Government Thrift Savings Plan

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("tsp","c");       #get value of C - Common Stock Index Investment Fund
    %info = Finance::Quote->fetch("tsp","l2040");   #get value of the L2040 Lifecycle Fund
    %info = Finance::Quote->fetch("tsp","lincome"); #get value of the LINCOME Lifecycle Fund

=head1 DESCRIPTION

This module fetches fund information from the "Thrift Savings Plan"

    http://www.tsp.gov

The quote symbols are

    C          common stock fund
    F          fixed income fund
    G          government securities fund
    I          international stock fund
    S          small cap stock fund
    LX         lifecycle fund X (eg 2050 or INCOME)

=head1 LABELS RETURNED

The following labels are returned by Finance::Quote::TSP :

    date        latest date, eg. "21/02/10"
    isodate     latest date, eg. "2010-02-21"
    last        latest available price, eg. "16.1053"
    currency    "USD"
    method      "tsp"
    source      TSP URL

=head1 SEE ALSO

Thrift Savings Plan, http://www.tsp.gov

=cut
