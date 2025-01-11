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

package Finance::Quote::CurrencyRates::CurrencyFreaks;

use strict;
use warnings;

use constant DEBUG => $ENV{DEBUG};
use constant TESTING => $ENV{TESTING};

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

  ### CurrencyFreaks->new args : $args

  # CurrencyFreaks is permitted to use an environment variable for API key 
  # (for backwards compatibility).
  # New modules can use the API_KEY from args.

  $this->{API_KEY} =
    $args->{API_KEY} if (ref $args eq 'HASH') and (exists $args->{API_KEY});
  $this->{API_KEY} =
    $ENV{'CURRENCYFREAKS_API_KEY'} if exists $ENV{'CURRENCYFREAKS_API_KEY'};

  # Return nothing if API_KEY not set
  return unless ($this->{API_KEY});

  return $this;

}

sub multipliers
{
  my ($this, $ua, $from, $to) = @_;

  my $reply = $ua->get('https://api.currencyfreaks.com/v2.0/rates/latest'
      . '?apikey=' . $this->{API_KEY}
      . '&symbols=' . ${from} . ',' . ${to}
  );
  
  my $body = $reply->content;
  my $reply_code = $reply->code;

  if (TESTING) {
    $body = '{
      "date": "2023-03-21 13:26:00+00",
      "base": "USD",
      "rates": {
          "EUR": "0.9278605451274349",
          "GBP": "0.8172754173817152",
          "PKR": "281.6212943333344",
          "USD": "1.0",
          "TST": "3000.0"
      }
    }';
    $reply_code = 200;
  }

  ### HTTP body: $body

  return unless ($reply_code == 200);

  my $json_data = decode_json ($body);

  if ( !$json_data->{'rates'}->{${from}} || !$json_data->{'rates'}->{${to}} ) {
    return;
  }

  # We really don't care what the base is as long as it is same.
  ### rates base: $json_data->{"base"}

  ### from: $to
  ### to: $json_data->{"base"}
  ### rate: ($json_data->{'rates'}->{${to}})

  ### from: $json_data->{"base"}
  ### to: $from
  ### rate: ($json_data->{'rates'}->{${from}})

  my $rate = 
    $json_data->{'rates'}->{${to}} / $json_data->{'rates'}->{${from}};
  
  return unless $rate + 0;

  # For small rates, request the inverse 
  if ($rate < 0.001) {
    ### Rate is too small, requesting inverse : $rate
    my ($a, $b) = $this->multipliers($ua, $to, $from);
    return ($b, $a);
  }

  # return actual multipliers that are relative to a third currency 
  return ($json_data->{'rates'}->{${from}}, $json_data->{'rates'}->{${to}});
}



1;

__END__

=head1 NAME

Finance::Quote::CurrencyRates::CurrencyFreaks - Obtain currency rates from
CurrencyFreaks.

=head1 SYNOPSIS

    use Finance::Quote;
    $q = Finance::Quote->new(currency_rates =>
        {order => ['CurrencyFreaks'], currencyfreaks => {API_KEY => ...} } );
    $value = $q->currency('18.99 EUR', 'USD');

=head1 DESCRIPTION

This module fetches currency rates from https://currencyfreaks.com/ provides 
data to Finance::Quote to convert the first argument to the equivalent value 
in the currency indicated by the second argument.

This module is not the default currency conversion module for a Finance::Quote
object. 

=head1 API_KEY

https://currencyfreaks.com/ requires users to register and obtain an API key,
which is also called a token.

The API key may be set by either providing a currencyfreaks hash inside the
currency_rates hash to Finance::Quote->new as in the above example, or by
setting the environment variable CURRENCYFREAKS_API_KEY.

=head1 Terms & Conditions

Use of https://currencyfreaks.com/ is governed by any terms & conditions of that 
site.

Finance::Quote is released under the GNU General Public License, version 2,
which explicitly carries a "No Warranty" clause.

=cut
