#!/usr/bin/perl -w

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

package Finance::Quote::CurrencyRates::AlphaVantage;

use strict;
use warnings;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use JSON;

# VERSION

sub parameters {
  return ('API_KEY');
}

sub new
{
  my $self = shift;
  my $class = ref($self) || $self;

  my $this = {};
  bless $this, $class;

  my $args = shift;

  ### AlphaVantage->new args : $args

  # AlphaVantage is the ONLY module permitted to use an environment variable
  # for API key (for backwards compatibility).  New modules MUST use the
  # API_KEY from args.

  $this->{API_KEY} = $ENV{'ALPHAVANTAGE_API_KEY'};
  $this->{API_KEY} = $args->{API_KEY} if (ref $args eq 'HASH') and (exists $args->{API_KEY});

  return $this;
}

sub multipliers
{
  my ($this, $ua, $from, $to) = @_;

  my $url = 'https://www.alphavantage.co/query?function=CURRENCY_EXCHANGE_RATE';
  my $try_cnt = 0;
  my $json_data;
  my $rate;
  do {
    $try_cnt += 1;
#   AlphaVantage is limiting free/basic api use to one query per second.
#   sleep 2 ensures a query for currency exchange is not immediately
#   following a price query.
    sleep 2;
    my $reply = $ua->get($url
        . '&from_currency=' . ${from}
        . '&to_currency=' . ${to}
        . '&apikey=' . $this->{API_KEY});

    return unless ($reply->code == 200);

    my $body = $reply->content;

    $json_data = JSON::decode_json $body;
    if ( !$json_data || $json_data->{'Error Message'} ) {
      return;
    }

    ### JSON: $json_data
  
    sleep (20) if (($try_cnt < 5) && ($json_data->{'Note'}));
  } while (($try_cnt < 5) && ($json_data->{'Note'}));

  if( !$json_data->{'Realtime Currency Exchange Rate'} ) {
    ### No data in JSON
	  $rate = 0.0;
  } else {
  $rate =
    $json_data->{'Realtime Currency Exchange Rate'}->{'5. Exchange Rate'};
  }

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

Finance::Quote::CurrencyRates::AlphaVantage - Obtain currency rates from
https://www.alphavantage.co

=head1 SYNOPSIS

    use Finance::Quote;
    
    $q = Finance::Quote->new(currency_rates => {order        => ['AlphaVantage'],
                                                alphavantage => {API_KEY => ...}});

    $value = $q->currency('18.99 EUR', 'USD');

=head1 DESCRIPTION

This module fetches currency rates from https://www.alphavantage.co and
provides data to Finance::Quote to convert the first argument to the equivalent
value in the currency indicated by the second argument.

This module is the default currency conversion module for a Finance::Quote
object. 

=head1 API_KEY

https://www.alphavantage.co requires users to register and obtain an API key,
which is also called a token.  

The API key may be set by either providing a alphavantage hash inside the
currency_rates hash to Finance::Quote->new as in the above example, or by
setting the environment variable ALPHAVANTAGE_API_KEY.

=head1 Terms & Conditions

Use of https://www.alphavantage.co is governed by any terms & conditions of
that site.

Finance::Quote is released under the GNU General Public License, version 2,
which explicitly carries a "No Warranty" clause.

=cut
