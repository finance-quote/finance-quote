#!/usr/bin/perl -w
# vi: set ts=2 sw=2 ic noai expandtab showmode showmatch:

#    This file is part of Finance::Quote.
#
#    Finance::Quote is free software: you can redistribute it and/or
#    modify it under the terms of the GNU General Public License as
#    published by the Free Software Foundation, either version 2 of
#    the License, or (at your option) any later version.
#
#    Finance::Quote is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#    General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with Finance::Quote.
#    If not, see <https://www.gnu.org/licenses/>.

#    Copyright (C) 2026, FXMacroData

#    Changes:
#    2026-11-12 - Initial version.

package Finance::Quote::CurrencyRates::FXMacroData;

use strict;
use warnings;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use JSON;

# VERSION

my $FXMACRODATA_URL_HEAD = 'https://api.fxmacrodata.com/v1/forex/';

# Below this rate the inverse pair is requested as well, so that a small
# rate does not lose significant digits.
my $SMALL_RATE = 0.001;

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

  $this->{API_KEY} = $ENV{'FXMACRODATA_API_KEY'};
  $this->{API_KEY} = $args->{API_KEY} if (ref $args eq 'HASH') and (exists $args->{API_KEY});

  return $this;
}

sub multipliers
{
  my ($this, $ua, $from, $to) = @_;

  return unless $this->{API_KEY};
  return unless defined $from and defined $to;

  $from = uc($from);
  $to   = uc($to);
  return unless $from =~ /^[A-Z]{3}$/ and $to =~ /^[A-Z]{3}$/;

  my $rate = $this->_latest_rate($ua, $from, $to);
  return unless $rate;

  if ($rate < $SMALL_RATE) {
    ### Rate is small, requesting the inverse pair : $rate
    my $inverse = $this->_latest_rate($ua, $to, $from);
    return ($inverse, 1.0) if $inverse;
  }

  return (1.0, $rate);
}

# Latest published rate: units of $quote per one unit of $base, or undef.
sub _latest_rate
{
  my ($this, $ua, $base, $quote) = @_;

  my $url = $FXMACRODATA_URL_HEAD . $base . '/' . $quote . '?limit=1';

  my $reply = $ua->get($url,
                       'Accept'    => 'application/json',
                       'X-API-Key' => $this->{API_KEY});

  ### URL: $url
  ### HTTP Status: $reply->code

  return unless ($reply->code == 200);

  my $json_data = eval { JSON::decode_json $reply->content };
  return unless ref $json_data eq 'HASH' and ref $json_data->{'data'} eq 'ARRAY';

  # Rows are ordered most recent first.
  my $row = $json_data->{'data'}->[0];
  return unless ref $row eq 'HASH' and defined $row->{'val'};

  my $rate = $row->{'val'};
  return unless $rate =~ /^\s*[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?\s*$/ and $rate > 0;

  ### Rate: $base . '/' . $quote . ' = ' . $rate . ' on ' . ($row->{'date'} // '?')

  return $rate + 0;
}

1;

__END__

=head1 NAME

Finance::Quote::CurrencyRates::FXMacroData - Obtain currency rates from
https://api.fxmacrodata.com/v1/forex/

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new(currency_rates => {order => ['FXMacroData'],
                                                fxmacrodata => {API_KEY => '...'}});
    $value = $q->currency('18.99 EUR', 'USD');

=head1 DESCRIPTION

This module fetches the latest daily official central-bank reference rate
for a currency pair from FXMacroData
(https://fxmacrodata.com/?utm_source=github&utm_medium=referral&utm_campaign=finance-quote-currencyrates&utm_content=pod)
and provides data to Finance::Quote to convert the first argument to the
equivalent value in the currency indicated by the second argument.

Each request reads https://api.fxmacrodata.com/v1/forex/<FROM>/<TO>?limit=1
and uses the most recent published rate. Rates are published on business
days only, so on weekends and holidays the rate of the last publication day
is used. When the rate is smaller than 0.001 the inverse pair is requested
as well, to keep its significant digits.

The currencies served are listed by the keyless catalogue endpoint
https://api.fxmacrodata.com/v1/data_catalogue/<CURRENCY>. Pairs that are
not served fail, and Finance::Quote then tries the next module in the
currency_rates order, if any.

This module is not the default currency conversion module for a
Finance::Quote object. It can be utilized by setting the environment
variable FQ_CURRENCY=FXMacroData.

=head1 API_KEY

https://api.fxmacrodata.com/v1/forex/ requires an API key, sent in the
X-API-Key request header. Keys are available from
https://fxmacrodata.com/subscribe?utm_source=github&utm_medium=referral&utm_campaign=finance-quote-currencyrates&utm_content=pod

The API key may be set by either providing a fxmacrodata hash inside the
currency_rates hash to Finance::Quote->new as in the above example, or by
setting the environment variable FXMACRODATA_API_KEY.

=head1 Terms & Conditions

Use of https://api.fxmacrodata.com/ is governed by the FXMacroData terms of
service:
https://fxmacrodata.com/terms?utm_source=github&utm_medium=referral&utm_campaign=finance-quote-currencyrates&utm_content=pod

Finance::Quote is released under the GNU General Public License, version 2,
which explicitly carries a "No Warranty" clause.

=cut
