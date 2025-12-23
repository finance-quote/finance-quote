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

#    Copyright (C) 2025, Bruce Schuck <bschuck@asgard-systems.com>

#    Changes:
#    2025-12-22 - Initial version. Base code opied from
#    CurrencyRates/FinanceAPI.pm

package Finance::Quote::CurrencyRates::TwelveData;

use strict;
use warnings;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use JSON;

# VERSION

my $TWELVEDATA_URL_HEAD = 'https://api.twelvedata.com/exchange_rate?symbol=';

sub new
{
  my $self = shift;
  my $class = ref($self) || $self;

  my $this = {};
  bless $this, $class;

  my $args = shift;

  ### TwelveData->new args : $args

  # TwelveData is permitted to use an environment variable for API key 
  # (for backwards compatibility).
  # New modules should use the API_KEY from args.

  $this->{API_KEY} = $ENV{'TWELVEDATA_API_KEY'};
  $this->{API_KEY} = $args->{API_KEY} if (ref $args eq 'HASH') and (exists $args->{API_KEY});

  return $this;
}

sub multipliers
{
  my ($this, $ua, $from, $to) = @_;

  my $json_data;
  my $rate;

# Set headers. API key is sent as a header.
  my @ua_headers = (
    'Accept' => 'application/json',
  );

  my $reply = $ua->get($TWELVEDATA_URL_HEAD
      . ${from}
      . '%2F'
      . ${to}
      . '&apikey='
      . $this->{API_KEY}, @ua_headers);

  ### HTTP Status: $reply->code
  return unless ($reply->code == 200);

  my $body = $reply->content;

  $json_data = JSON::decode_json $body;

  ### JSON: $json_data

  if ( !$json_data || !$json_data->{'rate'} ) {
    return;
  }

  $rate =
    $json_data->{'rate'};

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

Finance::Quote::CurrencyRates::TwelveData - Obtain currency rates from
https://api.twelvedata.com/exchange_rate

=head1 SYNOPSIS

    use Finance::Quote;
    
    $q = Finance::Quote->new(currency_rates =>
         {order => ['TwelveData'],
          twelvedata => {API_KEY => ...}
         });

    $value = $q->currency('18.99 EUR', 'USD');

=head1 DESCRIPTION

This module fetches currency rates from
https://api.twelvedata.com/exchange_rate provides data to Finance::Quote
to convert the first argument to the equivalent value in the currency
indicated by the second argument.

This module is not the default currency conversion module for a Finance::Quote
object. 
It can be utilized by setting the environment variable FQ_CURRENCY=TwelveData.

=head1 API_KEY

https://api.twelvedata.com/exchange_rate requires users to register and obtain an API key.  

The API key can be set by setting the Environment variable
"TWELVEDATA_API_KEY" or providing a 'twelvedata' hash inside the
'currency_rates' hash to Finance::Quote->new as in the above example.

=head1 Terms & Conditions

Use of https://api.twelvedata.com/exchange_rate is
governed by any terms & conditions of that site.

Finance::Quote is released under the GNU General Public License, version 2,
which explicitly carries a "No Warranty" clause.

=cut
