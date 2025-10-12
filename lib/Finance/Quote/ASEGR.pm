#!/usr/bin/perl -w
#    vi: set ts=2 sw=2 noai ic expandtab showmode showmatch: 
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

#   Changes:
#   Rewrite: 2025-10-11 - Many changes to web site, Bruce Schuck

package Finance::Quote::ASEGR;

use strict;
use warnings;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use LWP::UserAgent;
use Text::Template;
use JSON qw( decode_json );

# VERSION 

our $DISPLAY    = 'ASEGR - Athens Exchange Group, GR';
our @LABELS     = qw/symbol name open high low last date volume currency method/;
our $METHODHASH = {subroutine => \&asegr, 
                   display => $DISPLAY, 
                   labels => \@LABELS};

my $URL   = Text::Template->new(TYPE => 'STRING', SOURCE => 'https://www.athexgroup.gr/en/market-data/instruments/{$instrument}/inbroker');

my @instruments = qw/stocks bonds etfs lending derivatives indices/;
my ( %jsondata, %info );

sub methodinfo {
  return ( 
   asegr  => $METHODHASH,
   greece => $METHODHASH,
   europe => $METHODHASH,
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

# Since %jsondata and %info are global to this module
# pass in the instrument and symbol to search for the data
sub find_symbol {
  my $instrument = shift;
  my $symbol = shift;
  my $quoter = shift;

  my $searchparams = $instrument . $symbol;
  ### [<now>] Searching for: $searchparams

  foreach my $item( @{$jsondata{$instrument}->{'data'}} ) {
    if ($item->{instrCode} eq $symbol) {
      $info{ $symbol, 'success' } = 1;
      $info{ $symbol, 'symbol' } = $symbol;
      $info{ $symbol, 'method' } = 'asegr';
      $info{ $symbol, 'instrument' } = $instrument;
      if ($instrument ne 'stocks') {
        $info{ $symbol, 'name' } = $item->{'instrName'};
      } else {
        $info{ $symbol, 'name' } = $item->{'companyName'};
      }
      $info{ $symbol, 'currency' } = $item->{'currCode'};
      $info{ $symbol, 'last' } = $item->{'closePrice'};
      $info{ $symbol, 'close' } = $item->{'closePrice'};
      $info{ $symbol, 'high' } = $item->{'highPrice'};
      $info{ $symbol, 'low' } = $item->{'lowPrice'};
      $info{ $symbol, 'open' } = $item->{'openPrice'};
      $info{ $symbol, 'isodate' } = $item->{'tradeDate'};
      my $isodate = $item->{'tradeDate'};
      $quoter->store_date( \%info, $symbol, { isodate => $isodate } );
      return 1;
    }
  }

  return 0;

}

sub asegr {
  my $quoter  = shift;
  my @symbols = @_;
  my $ua      = $quoter->user_agent();
  my ($url, $reply);

  my %table;
  my $index = 0;

  SYMBOL: foreach my $symbol (@symbols) {
    ### [<now>] Symbol: $symbol
#    $info{ $symbol, 'success' } = 0;
#    $info{ $symbol, 'errormsg' } = 'Symbol not found';
    INSTRUMENT: foreach my $instrument (@instruments) {
#     if $jsondata{$instrument} not defined, fetch data
      if (!defined ($jsondata{$instrument}) ) {
        $url = $URL->fill_in(HASH => {instrument => $instrument});
        ### [<now>] Fetching url: $url
        $reply = $ua->get($url);
        if ($reply->is_success) {
          $jsondata{$instrument} = decode_json($reply->content);
          ### [<now>] jsondata: $jsondata{$instrument}
          find_symbol($instrument, $symbol, $quoter) && next SYMBOL;
        } else {
          next INSTRUMENT;
        }
      } else {
        find_symbol($instrument, $symbol, $quoter) && next SYMBOL;
      }
    }
  }

  return wantarray() ? %info : \%info;
}

1;

=head1 NAME

Finance::Quote::ASEGR - Obtain quotes from Athens Exchange Group

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("asegr","minoa");  # Only query ASEGR
    %info = Finance::Quote->fetch("greece","aaak");  # Failover to other sources OK.

=head1 DESCRIPTION

This module fetches information from https://www.athexgroup.gr.

This module is loaded by default on a Finance::Quote object. It's also possible
to load it explicitly by placing 'asegr' in the argument list to
Finance::Quote->new().

This module provides both the 'asegr' and 'greece' fetch methods.

=head1 LABELS RETURNED

The following labels may be returned: symbol date isodate close volume high low isin.

=head1 Terms & Conditions

Use of www.athexgroup.gr is governed by any terms & conditions of that site.

Finance::Quote is released under the GNU General Public License, version 2,
which explicitly carries a "No Warranty" clause.

=cut
