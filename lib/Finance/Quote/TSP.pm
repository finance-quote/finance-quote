#!/usr/bin/perl -w
# vi: set ts=2 sw=2 noai expandtab ic showmode showmatch:  
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

use strict;

use constant DEBUG => $ENV{DEBUG}; 
use if DEBUG, 'Smart::Comments'; 

package Finance::Quote::TSP;

use vars qw( $TSP_URL $TSP_MAIN_URL @HEADERS );

use LWP::UserAgent;
use HTTP::Request::Common;
use POSIX;

# VERSION

# URLs of where to obtain information
$TSP_URL      = 'https://www.tsp.gov/data/fund-price-history.csv';
$TSP_MAIN_URL = 'http://www.tsp.gov';
@HEADERS      = ('user-agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/102.0.5005.61 Safari/537.36');

our $DISPLAY    = 'TSP - US Gov Thrift Savings Plan';
our @LABELS     = qw/name date isodate currency close/;
our $METHODHASH = {subroutine => \&tsp, 
                   display    => $DISPLAY, 
                   labels     => \@LABELS};

sub methodinfo {
  return ( 
      tsp => $METHODHASH,
  );
}

sub labels {
  my %m = methodinfo();
  return map {$_ => [@{$m{$_}{labels}}] } keys %m;
}

sub methods {
  my %m = methodinfo();
  return map {$_ => $m{$_}{subroutine} } keys %m;
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
  my @line;

  # Ask for the last 7 days
  my $startdate = strftime("%Y-%m-%d", localtime (time - 7*24*3600));
  my $enddate   = strftime("%Y-%m-%d", localtime time);

  my $ua    = $quoter->user_agent;
  my $url   = "$TSP_URL?startdate=$startdate&enddate=$enddate&Lfunds=1&InvFunds=1&download=1";
  my $reply = $ua->get($url, @HEADERS);
  ### [<now>] url  : $url
  ### [<now>] reply: $reply
  
  unless (($reply->is_success) && (@line = split(/\n/, $reply->content)) && (@line > 1)) {
    foreach my $symbol (@symbols) {
      $info{$symbol, "success"}  = 0;
      $info{$symbol, "errormsg"} = "TSP fetch failed. No data for $symbol.";
    }
    ### Failure: %info
    return wantarray ? %info : \%info;
  }

  my @header = split(/,/, $line[0]);
  my %column = map { format_name($header[$_]) => $_ } 0 .. $#header;
  my @latest = split(/,/, $line[1]);

  ### [<now>]  header: @header 
  ### [<now>]  column: %column 
  ### [<now>]  latest: @latest 

  foreach (@symbols) {
    my $symbol = lc $_;

    if(exists $column{$symbol}) {
      $info{$_, 'success'} = 1;
      $quoter->store_date(\%info, $_, {isodate => $latest[$column{'date'}]});
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

    %info = $q->fetch('tsp','c');       #get value of C - Common Stock Index Investment Fund
    %info = $q->fetch('tsp','l2040');   #get value of the L2040 Lifecycle Fund
    %info = $q->fetch('tsp','lincome'); #get value of the LINCOME Lifecycle Fund

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
