#!/usr/bin/perl -w
# vi: set ts=2 sw=2 ic noai expandtab showmode showmatch:

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

#    Copyright (C) 2026, Madhushan Basnayaka (AllRatesToday)

#    Changes:
#    2026-10-29 - Initial version. Base code copied from
#    CurrencyRates/Frankfurter.pm

package Finance::Quote::CurrencyRates::AllRatesToday;

use strict;
use warnings;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use JSON;

# VERSION

my $ALLRATESTODAY_URL_HEAD = 'https://allratestoday.com/api/';

sub parameters {
  return ('BANK', 'API_KEY');
}

sub new
{
  my $self = shift;
  my $class = ref($self) || $self;

  my $this = {};
  bless $this, $class;

  my $args = shift;

  ### AllRatesToday->new args : $args

  # Optional: the code of a central bank whose official table should be
  # used instead of the ECB reference rates, e.g. 'sama' or 'rbnz'.
  $this->{BANK} = $ENV{'ALLRATESTODAY_BANK'};
  $this->{BANK} = $args->{BANK} if (ref $args eq 'HASH') and (exists $args->{BANK});
  $this->{BANK} = lc($this->{BANK}) if defined $this->{BANK};

  # Optional: an AllRatesToday API key. With a key the central-bank table is
  # read from the keyed endpoint, which the terms allow for any use; the
  # keyless endpoints are for non-commercial use with a visible link.
  $this->{API_KEY} = $ENV{'ALLRATESTODAY_API_KEY'};
  $this->{API_KEY} = $args->{API_KEY} if (ref $args eq 'HASH') and (exists $args->{API_KEY});

  return $this;
}

sub multipliers
{
  my ($this, $ua, $from, $to) = @_;

  return $this->_bank_multipliers($ua, $from, $to) if $this->{BANK};

  # ECB reference table re-based on the requested currency; one request
  # covers every quote currency.
  my $json_data = $this->_get_json($ua, 'open/latest/' . $from);

  if ($json_data and ref $json_data->{'rates'} eq 'HASH'
      and $json_data->{'rates'}->{$to}) {
    my $rate = $json_data->{'rates'}->{$to};
    ### Rate from JSON: $rate
    return unless $rate + 0;
    return (1.0, $rate);
  }

  # $from is not one of the table's base codes; the pair may still exist
  # the other way around.
  $json_data = $this->_get_json($ua, 'open/latest/' . $to);

  if ($json_data and ref $json_data->{'rates'} eq 'HASH'
      and $json_data->{'rates'}->{$from}) {
    my $inverse = $json_data->{'rates'}->{$from};
    ### Inverse rate from JSON: $inverse
    return unless $inverse + 0;
    return ($inverse, 1.0);
  }

  return;
}

# Official table of one central bank. Every row says "1 base = value quote"
# and carries a rate type. Banks publish either foreign-per-home (base varies,
# quote is the home currency) or home-per-foreign (base is the home currency,
# quote varies), so the home currency is the code common to all rows. One
# rate type is used per pair: reference, else middle/mid/official, else the
# mean of a buy and a sell row.
sub _bank_multipliers
{
  my ($this, $ua, $from, $to) = @_;

  my $path = $this->{API_KEY}
    ? 'v1/central-bank/' . $this->{BANK} . '/latest'
    : 'open/central-bank/' . $this->{BANK};
  my $json_data = $this->_get_json($ua, $path);

  return unless $json_data and ref $json_data->{'rates'} eq 'ARRAY';

  my %by_pair;
  foreach my $row (@{$json_data->{'rates'}}) {
    next unless ref $row eq 'HASH' and $row->{'base'} and $row->{'quote'}
                and $row->{'value'} and $row->{'value'} > 0;
    my $pair = uc($row->{'base'}) . '/' . uc($row->{'quote'});
    $by_pair{$pair}{lc($row->{'type'} || 'reference')} = $row->{'value'};
  }

  my (%seen, @rows);
  foreach my $pair (keys %by_pair) {
    my $types = $by_pair{$pair};
    my $value;
    foreach my $type ('reference', 'middle', 'mid', 'official') {
      $value = $types->{$type}, last if exists $types->{$type};
    }
    if (not defined $value and exists $types->{'buy'} and exists $types->{'sell'}) {
      $value = ($types->{'buy'} + $types->{'sell'}) / 2;
    }
    $value = (values %$types)[0] if not defined $value and keys %$types == 1;
    next unless defined $value;

    my ($base, $quote) = split '/', $pair;
    push @rows, [$base, $quote, $value];
    $seen{$base}++;
    $seen{$quote}++;
  }
  return unless @rows;

  my ($home) = sort { $seen{$b} <=> $seen{$a} or $a cmp $b } keys %seen;

  # %units: home-currency units per one unit of each currency
  my %units = ($home => 1.0);
  foreach my $row (@rows) {
    my ($base, $quote, $value) = @$row;
    if ($quote eq $home) {
      $units{$base} = $value;
    }
    elsif ($base eq $home) {
      $units{$quote} = 1.0 / $value;
    }
  }

  ### Bank table home : $home
  ### Bank table units : \%units

  return unless $units{$from} and $units{$to};

  # amount * (units{$from} / units{$to}) == amount in $to
  return ($units{$to}, $units{$from});
}

sub _get_json
{
  my ($this, $ua, $path) = @_;

  my $url = $ALLRATESTODAY_URL_HEAD . $path;

  my @headers = (
    'Accept'     => 'application/json',
    'User-Agent' => 'finance-quote-allratestoday/1.0');
  push @headers, 'Authorization' => 'Bearer ' . $this->{API_KEY} if $this->{API_KEY};

  my $reply = $ua->get($url, @headers);

  ### URL: $url
  ### HTTP Status: $reply->code

  return unless ($reply->code == 200);

  my $json_data = eval { JSON::decode_json $reply->content };

  ### JSON: $json_data

  return $json_data;
}

1;

=head1 NAME

Finance::Quote::CurrencyRates::AllRatesToday - Obtain currency rates from
https://allratestoday.com/api/open/

=head1 SYNOPSIS

    use Finance::Quote;

    # European Central Bank reference rates (30 currencies)
    $q = Finance::Quote->new(currency_rates => {order => ['AllRatesToday']});
    $value = $q->currency('18.99 EUR', 'USD');

    # Official table of one central bank, e.g. the Saudi Central Bank
    $q = Finance::Quote->new(currency_rates => {order => ['AllRatesToday'],
                                                allratestoday => {BANK => 'sama'}});
    $value = $q->currency('100.00 SAR', 'USD');

=head1 DESCRIPTION

This module fetches currency rates from the keyless AllRatesToday open
endpoints and provides data to Finance::Quote to convert the first argument
to the equivalent value in the currency indicated by the second argument.

Without options it uses the European Central Bank reference table re-based
on the source currency (https://allratestoday.com/api/open/latest/EUR).

With the BANK option it uses the latest official table published by that
central bank (https://allratestoday.com/api/open/central-bank/sama). Codes
are listed at https://allratestoday.com/central-bank-rates-api/institutions/
and include banks that other free aggregators do not carry, such as the
Saudi Central Bank (sama), Central Bank of the UAE (cbuae), Qatar Central
Bank (qcb), Bank of Korea (bok), Reserve Bank of New Zealand (rbnz), State
Bank of Vietnam (sbv) and Bangladesh Bank (bb). When a bank publishes
several rate types for a pair, the reference rate is used, else the
middle/official rate, else the mean of the buy and sell rates.

This module is not the default currency conversion module for a
Finance::Quote object. It can be utilized by setting the environment
variable FQ_CURRENCY=AllRatesToday. The bank can also be set with the
environment variable ALLRATESTODAY_BANK, the API key with
ALLRATESTODAY_API_KEY.

=head1 API_KEY

The keyless endpoints do not require an API key. With the optional API_KEY
option (free or paid key from https://allratestoday.com/register) the
central-bank table is read from the keyed endpoint
https://allratestoday.com/api/v1/central-bank/<bank>/latest instead.

=head1 Terms & Conditions

Use of https://allratestoday.com/api/ is governed by the terms of that site
(https://allratestoday.com/terms/). Keyless use is for non-commercial use
and asks for a visible link to https://allratestoday.com where the rates are
displayed; commercial use needs a key on a paid plan.

Finance::Quote is released under the GNU General Public License, version 2,
which explicitly carries a "No Warranty" clause.

=cut
