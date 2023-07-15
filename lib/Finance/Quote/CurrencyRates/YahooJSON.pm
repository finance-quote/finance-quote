#!/usr/bin/perl -w
# vi: set ts=2 sw=2 ic noai showmode showmatch:  

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

#    Copyright (C) 2023, Bruce Schuck <bschuck@asgard-systems.com>

package Finance::Quote::CurrencyRates::YahooJSON;

use strict;
use warnings;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use JSON;

# VERSION

my $YIND_URL_HEAD = 'https://query2.finance.yahoo.com/v11/finance/quoteSummary/?symbol=';
my $YIND_URL_TAIL = '&modules=price';

sub new
{
  my $self = shift;
  my $class = ref($self) || $self;

  my $this = {};
  bless $this, $class;

  my $args = shift;

  ### YahooJSON->new args : $args

  return $this;
}

sub multipliers
{
  my ($this, $ua, $from, $to) = @_;

  my $json_data;
  my $rate;
  my $reply = $ua->get($YIND_URL_HEAD
      . ${from}
      . ${to}
      . '%3DX'
      . $YIND_URL_TAIL);

  ### HTTP Status: $reply->code
  return unless ($reply->code == 200);

  my $body = $reply->content;

  $json_data = JSON::decode_json $body;

  ### JSON: $json_data

  if ( !$json_data || !$json_data->{'quoteSummary'}->{'result'}->[0]->{'price'}->{'regularMarketPrice'}{'raw'} ) {
    return;
  }

  $rate =
    $json_data->{'quoteSummary'}->{'result'}->[0]->{'price'}->{'regularMarketPrice'}{'raw'};

  ### Rate from JSON: $rate

  return unless $rate + 0;

  # For small rates, request the inverse 
  if ($rate < 0.001) {
    ### Rate is too small, requesting inverse : $rate
    my ($a, $b) = $this->multipliers($ua, $to, $from);
    return ($b, $a);
  }

  return (1.0, $rate);
}


1;

=head1 NAME

Finance::Quote::CurrencyRates::YahooJSON - Obtain currency rates from
https://query2.finance.yahoo.com/v11/finance/quoteSummary/...?modules=price

=head1 SYNOPSIS

    use Finance::Quote;
    
    $q = Finance::Quote->new(currency_rates => {order => ['YahooJSON']});

    $value = $q->currency('18.99 EUR', 'USD');

=head1 DESCRIPTION

This module fetches currency rates from
https://query2.finance.yahoo.com/v11/finance/quoteSummary/...?modules=price
provides data to Finance::Quote to convert the first argument to the equivalent
value in the currency indicated by the second argument.

This module is not the default currency conversion module for a Finance::Quote
object. 

=head1 Terms & Conditions

Use of https://query2.finance.yahoo.com/v11/finance/quoteSummary/...?modules=price is
governed by any terms & conditions of that site.

Finance::Quote is released under the GNU General Public License, version 2,
which explicitly carries a "No Warranty" clause.

=cut
