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

use vars qw( $TSP_URL $TSP_MAIN_URL %TSP_FUND_COLUMNS %TSP_FUND_NAMES);

use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;

# VERSION

# URLs of where to obtain information

$TSP_URL = 'https://www.tsp.gov/InvestmentFunds/FundPerformance/index.html';
$TSP_MAIN_URL=("http://www.tsp.gov");

# ENHANCE-ME: The decade target funds like 2020 appear and disappear.
# Better not to hard code them.
#
%TSP_FUND_COLUMNS = (
    L2050   => "L 2050",
    L2040   => "L 2040",
    L2030   => "L 2030",
    L2020   => "L 2020",
    LINCOME => "L INCOME",
    G       => "G FUND",
    F       => "F FUND",
    C       => "C FUND",
    S       => "S FUND",
    I       => "I FUND" );

%TSP_FUND_NAMES = (
    L2050    => 'Lifecycle 2050 Fund',
    L2040    => 'Lifecycle 2040 Fund',
    L2030    => 'Lifecycle 2030 Fund',
    L2020    => 'Lifecycle 2020 Fund',
    LINCOME  => 'Lifecycle Income Fund',
    G        => 'Government Securities Investment Fund',
    F        => 'Fixed Income Index Investment Fund',
    C        => 'Common Stock Index Investment Fund',
    S        => 'Small Capitalization Stock Index Investment Fund',
    I        => 'International Stock Index Investment Fund' );

sub methods { return (tsp => \&tsp) }

{
  my @labels = qw/name date isodate currency close/;
  sub labels { return (tsp => \@labels); }
}

# ==============================================================================
sub tsp {
  my $quoter = shift;
  my @symbols = @_;

  return unless @symbols;

  my(%info, %fundrows);
  my($ua, $reply, $row, $te, $ts, $second_row);

  $ua = $quoter->user_agent;
  $reply = $ua->request(GET $TSP_URL);
  return unless ($reply->is_success);
  $te = HTML::TableExtract->new( headers =>
      ["Date", values %TSP_FUND_COLUMNS] );

  $te->parse($reply->content);

  # First row is newest data, older data follows, maybe there
  # should be some way to get it (in addition to the second_row "close")
  $ts = $te->first_table_found
    || die 'TSP data table not recognised';
  $row = $ts->row(0);
  $second_row = $ts->row(1);

  # Make a hash that maps the order the columns are in
  for(my $i=1; my $key = each %TSP_FUND_COLUMNS ; $i++) {
    $fundrows{$key} = $i;
  }
  
  foreach (@symbols) {
    my $symbol = uc $_;

    if(exists $fundrows{$symbol}) {
      $info{$_, 'success'} = 1;
      $info{$_, 'name'} = $TSP_FUND_NAMES{$symbol};
      $quoter->store_date(\%info, $_, {usdate => $$row[0]});
      ($info{$_, 'last'} = $second_row->[$fundrows{$symbol}]) =~ s/[^0-9]*([0-9.,]+).*/$1/s;
      $info{$_, 'currency'} = 'USD';
      $info{$_, 'method'} = 'tsp';
      $info{$_, 'source'} = $TSP_MAIN_URL;
      $info{$_, 'symbol'} = $_;
    } 
    else {
      $info{$_, 'success'} = 0;
      $info{$_, 'errormsg'} = "Fund name unknown";
    }
  }
  return %info if wantarray;
  return \%info;
}
1;

=head1 NAME

Finance::Quote::TSP Obtain fund prices for US Federal Government Thrift Savings Plan

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("tsp","c"); #get value of C "Common Stock Index Investment" Fund

=head1 DESCRIPTION

This module fetches fund information from the "Thrift Savings Plan"

    http://www.tsp.gov

using its fund prices page

    https://www.tsp.gov/investmentfunds/shareprice/sharePriceHistory.shtml

The quote symbols are

    C          common stock fund
    F          fixed income fund
    G          government securities fund
    I          international stock fund
    S          small cap stock fund
    L2020      lifecycle fund year 2020
    L2030      lifecycle fund year 2030
    L2040      lifecycle fund year 2040
    L2050      lifecycle fund year 2050
    LINCOME    lifecycle income fund

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::TSP :

    name        eg. "Lifecycle 2050 Fund"
    date        latest date, eg. "21/02/10"
    isodate     latest date, eg. "2010-02-21"
    last        latest available price, eg. "16.1053"
    currency    "USD"
    method      "tsp"
    source      TSP URL

=head1 SEE ALSO

Thrift Savings Plan, http://www.tsp.gov

=cut
