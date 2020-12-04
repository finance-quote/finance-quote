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

package Finance::Quote::CurrencyRates::ECB;

use strict;
use warnings;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use XML::LibXML;

# VERSION

sub new
{
  my $self = shift;
  my $class = ref($self) || $self;

  my $this = {};
  bless $this, $class;

  return $this;
}

sub multipliers
{
  my ($this, $ua, $from, $to) = @_;

  unless (exists $this->{cache}) {
    my $url = 'https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml';

    my $reply = $ua->get($url);

    return unless ($reply->code == 200);
    my $xml = XML::LibXML->load_xml(string => $reply->content);

    $this->{cache}        = {map {$_->getAttribute('currency'), $_->getAttribute('rate')} $xml->findnodes('//*[@currency]')};
    $this->{cache}->{EUR} = 1.0;
    
    ### cache : $this->{cache}
  }


  if (exists $this->{cache}->{$from} and exists $this->{cache}->{$to}) {
    ### from : $from, $this->{cache}->{$from} 
    ### to   : $to, $this->{cache}->{$to}
    return ($this->{cache}->{$from}, $this->{cache}->{$to});
  }

  ### At least one code not found: $from, $to

  return;
}

1;

=head1 NAME

Finance::Quote::CurrencyRates::ECB - Obtain currency rates from
https://www.ecb.europa.eu

=head1 SYNOPSIS

    use Finance::Quote;
    
    $q = Finance::Quote->new(currency_rates => {order => ['ECB']});

    $value = $q->currency('18.99 EUR', 'CAD');

=head1 DESCRIPTION

This module fetches currency rates from https://www.ecb.europa.eu and
provides data to Finance::Quote to convert the first argument to the equivalent
value in the currency indicated by the second argument.

The European Central Bank provides a small list of currencies, quoted
against the Euro. This module caches the table of rates for the lifetime
of the Finance::Quote object after the first currency conversion.

=head1 Terms & Conditions

Use of https://www.ecb.europa.eu is governed by any terms & conditions of that
site.

Finance::Quote is released under the GNU General Public License, version 2,
which explicitly carries a "No Warranty" clause.

=cut
