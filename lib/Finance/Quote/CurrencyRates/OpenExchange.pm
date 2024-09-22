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

package Finance::Quote::CurrencyRates::OpenExchange;

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

  ### OpenExchange->new args : $args

  $this->{API_KEY} = $ENV{'OPENEXCHANGE_API_KEY'};

  $this->{API_KEY} =
    $args->{API_KEY} if (ref $args eq 'HASH') and (exists $args->{API_KEY});
  $this->{refresh} = 0;
  $this->{refresh} = not $args->{cache} if exists $args->{cache};

  # Return nothing if API_KEY not set
  return unless ($this->{API_KEY});

  ### API_KEY: $this->{API_KEY}

  return $this;

} # end new

sub multipliers
{
  my ($this, $ua, $from, $to) = @_;

  if ($this->{refresh} or not exists $this->{cache}) {
    my $url = "https://openexchangerates.org/api/latest.json?app_id=$this->{API_KEY}";
    my $reply = $ua->get($url);

    return unless ($reply->code == 200);

    my $body = $reply->content;

    my $json_data = JSON::decode_json $body;
    if ( !$json_data || $json_data->{error} || not exists $json_data->{rates}) {
      ### OpenExchange error : $json_data->{description}
      return;
    }

    $this->{cache} = $json_data->{rates};
    ### OpenExchange rates: $this->{cache}
  }


  if (exists $this->{cache}->{$from} and exists $this->{cache}->{$to}) {
    ### from : $from, $this->{cache}->{$from} 
    ### to   : $to, $this->{cache}->{$to}
    return ($this->{cache}->{$from}, $this->{cache}->{$to});
  }

  ### At least one code not found: $from, $to

  return;
} # end multipliers

1;

=head1 NAME

Finance::Quote::CurrencyRates::OpenExchange - Obtain currency rates from
https://openexchangerates.org

=head1 SYNOPSIS

    use Finance::Quote;
    
    $q = Finance::Quote->new(currency_rates =>
           {order => ['OpenExchange'], openexchange => {API_KEY => ...}}
         );

    $value = $q->currency('18.99 EUR', 'USD');

=head1 DESCRIPTION

This module fetches currency rates from https://openexchangerates.org and
provides data to Finance::Quote to convert the first argument to the equivalent
value in the currency indicated by the second argument.

This module caches the currency rates for the lifetime of the quoter object,
unless 'cache => 0' is included in the 'openexchange' options hash.

=head1 Currency Module Selection

The Finance::Quote currency method to be used can also be selected by setting
the environment variable FQ_CURRENCY.

    export FQ_CURRENCY=OpenExchange

=head1 API_KEY

https://openexchangerates.org requires users to register and obtain an API key.  Their free plan allows 1000 queries per month.

The API key can be set by setting the environment variable OPENEXCHANGE_API_KEY or by providing a 'openexchange' hash inside the
'currency_rates' hash to Finance::Quote->new as in the above example.

=head1 Terms & Conditions

Use of https://openexchangerates.org is governed by any terms & conditions of
that site.

Finance::Quote is released under the GNU General Public License, version 2,
which explicitly carries a "No Warranty" clause.

=cut
