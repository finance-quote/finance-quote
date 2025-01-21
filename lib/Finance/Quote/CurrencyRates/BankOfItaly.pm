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

package Finance::Quote::CurrencyRates::BankOfItaly;

use strict;
use warnings;

use constant DEBUG => $ENV{DEBUG};

use if DEBUG, 'Smart::Comments', '###';

use JSON;

# VERSION

sub new
{
  my $self = shift;
  my $class = ref($self) || $self;

  my $this = {};
  bless $this, $class;

  my $args = shift;

  ### BankOfItaly->new args : $args

  return $this;
}

sub multipliers
{
  my ($this, $ua, $from, $to) = @_;

  my $reply = $ua->get('https://tassidicambio.bancaditalia.it/terzevalute-wf-web/rest/v1.0/latestRates?lang=en',
      "Accept" => "application/json"
  );
  
  my $body = $reply->content;
  my $reply_code = $reply->code;

  return unless ($reply_code == 200);

  my $json_data = decode_json ($body);

  ### json data: $json_data

  my $total_rec = $json_data->{'resultsInfo'}{'totalRecords'};

  return unless ($total_rec > 0);
  
  my ($from_rec, $to_rec);
  for my $i (0 .. $total_rec-1) {
    my $currency_rec = $json_data->{'latestRates'}[$i];
    if ($currency_rec->{'isoCode'} eq $from) {
      $from_rec = $currency_rec;
    }
    if ($currency_rec->{'isoCode'} eq $to) {
      $to_rec = $currency_rec;
    }

  }

  ### from rec: $from_rec
  ###   to rec: $to_rec

  if ( !$from_rec->{'usdRate'} || !$to_rec->{'usdRate'} ) {
  	return;
  }

  if ($from_rec->{'usdExchangeConventionCode'} eq "I") {
    $from_rec->{'usdRate'} = 1.0 / $from_rec->{'usdRate'};
  }

  if ($to_rec->{'usdExchangeConventionCode'} eq "I") {
    $to_rec->{'usdRate'} = 1.0 / $to_rec->{'usdRate'};
  }

  my $rate = 
    $to_rec->{'usdRate'} / $from_rec->{'usdRate'};
    
  return unless $rate + 0;

  # For small rates, request the inverse 
  if ($rate < 0.001) {
    ### Rate is too small, requesting inverse : $rate
    my ($a, $b) = $this->multipliers($ua, $to, $from);
    return ($b, $a);
  }

  return ($from_rec->{'usdRate'}, $to_rec->{'usdRate'});
}

1;

__END__

=head1 NAME

Finance::Quote::CurrencyRates::BankOfItaly - Obtain currency rates from
BankOfItaly (https://www.bancaditalia.it/compiti/operazioni-cambi/index.html)

=head1 SYNOPSIS

    use Finance::Quote;
    $q = Finance::Quote->new(currency_rates =>
        {order => ['BankOfItaly']} );
    $value = $q->currency('18.99 EUR', 'USD');

=head1 DESCRIPTION

This module fetches currency rates from 
https://www.bancaditalia.it/compiti/operazioni-cambi/index.html provides
data to Finance::Quote to convert the first argument to the equivalent value 
in the currency indicated by the second argument.

This module is not the default currency conversion module for a Finance::Quote
object. 

=head1 Terms & Conditions

Use of https://www.bancaditalia.it is governed by any terms & conditions of that 
site.

Finance::Quote is released under the GNU General Public License, version 2,
which explicitly carries a "No Warranty" clause.

=cut
