#!/usr/bin/perl -w
#
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

package Finance::Quote::Finnhub;

use strict;
use warnings;

use JSON qw( decode_json );
use HTTP::Request::Common;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments', '###';

# VERSION

my $FINNHUB_URL = 'https://finnhub.io/api/v1/';

our $DISPLAY    = 'Finnhub - finnhub.io';
our $FEATURES   = {'API_KEY' => 'registered user API key'};
our @LABELS     = qw/symbol name last open high low close net p_change date isodate currency method/;
our $METHODHASH = {subroutine => \&finnhub,
                   display    => $DISPLAY,
                   labels     => \@LABELS,
                   features   => $FEATURES};

sub methodinfo {
    return (
        finnhub => $METHODHASH,
        usa     => $METHODHASH,
        nyse    => $METHODHASH,
        nasdaq  => $METHODHASH,
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

sub finnhub {

  my $quoter = shift;
  my @stocks = @_;
  my (%info, $url, $reply);
  my $ua = $quoter->user_agent();

  # The API key (token) may be supplied either through a module specific
  # hash passed to Finance::Quote->new, or via the FINNHUB_API_KEY
  # environment variable.
  my $token = exists $quoter->{module_specific_data}->{finnhub}->{API_KEY}
            ? $quoter->{module_specific_data}->{finnhub}->{API_KEY}
            : $ENV{'FINNHUB_API_KEY'};

  foreach my $stock (@stocks) {

    $info{ $stock, 'symbol' } = $stock;

    if ( !defined $token ) {
      $info{ $stock, 'success' }  = 0;
      $info{ $stock, 'errormsg' } =
        'A Finnhub API key is required. Get a free key at https://finnhub.io';
      next;
    }

    # ---------------------------------------------------------------
    # Quote: the /quote endpoint returns the price and the unix
    # timestamp of the last trade. It is the only call required for a
    # price and date and works for equities and ETFs alike.
    #
    #   {"c":291.15,"d":-4.48,"dp":-1.5154,"h":297.14,"l":289.62,
    #    "o":296.04,"pc":295.63,"t":1781294400}
    #     c = current price   pc = previous close   t = unix timestamp
    # ---------------------------------------------------------------
    $url   = $FINNHUB_URL . 'quote?symbol=' . $stock . '&token=' . $token;
    $reply = $ua->request( GET $url );

    ### Quote reply: $reply->code, $reply->content

    unless ( $reply->code == 200 ) {
      $info{ $stock, 'success' }  = 0;
      $info{ $stock, 'errormsg' } =
          $reply->code == 401 ? 'Invalid Finnhub API key'
        : $reply->code == 429 ? 'Finnhub API rate limit reached'
        : 'HTTP error ' . $reply->code . ' fetching quote for ' . $stock;
      next;
    }

    my $quote = eval { decode_json( $reply->content ) };
    if ( $@ || !$quote ) {
      $info{ $stock, 'success' }  = 0;
      $info{ $stock, 'errormsg' } = "Finnhub returned no parseable data for $stock";
      next;
    }

    # An unknown symbol returns a price and timestamp of 0.
    unless ( $quote->{t} && $quote->{c} ) {
      $info{ $stock, 'success' }  = 0;
      $info{ $stock, 'errormsg' } = "Symbol $stock not found";
      next;
    }

    $info{ $stock, 'last' }     = $quote->{c};
    $info{ $stock, 'open' }     = $quote->{o}  if $quote->{o};
    $info{ $stock, 'high' }     = $quote->{h}  if $quote->{h};
    $info{ $stock, 'low' }      = $quote->{l}  if $quote->{l};
    $info{ $stock, 'close' }    = $quote->{pc} if $quote->{pc};
    $info{ $stock, 'net' }      = $quote->{d}  if defined $quote->{d};
    $info{ $stock, 'p_change' } = $quote->{dp} if defined $quote->{dp};
    $info{ $stock, 'method' }   = 'finnhub';

    my ( undef, undef, undef, $mday, $mon, $year ) = localtime( $quote->{t} );
    $quoter->store_date( \%info, $stock,
      { isodate => sprintf( '%d-%02d-%02d', $year + 1900, $mon + 1, $mday ) } );

    # ---------------------------------------------------------------
    # Company profile: best-effort lookup of the trading currency and
    # company name. profile2 covers listed companies; it returns an
    # empty object for ETFs and other instruments, so a missing value
    # is not treated as an error. The free tier is US focused, so the
    # currency defaults to USD when the profile does not supply one.
    # ---------------------------------------------------------------
    $url   = $FINNHUB_URL . 'stock/profile2?symbol=' . $stock . '&token=' . $token;
    $reply = $ua->request( GET $url );

    my $currency = 'USD';
    if ( $reply->code == 200 ) {
      my $profile = eval { decode_json( $reply->content ) };
      unless ( $@ ) {
        $info{ $stock, 'name' } = $profile->{name} if $profile->{name};
        $currency = $profile->{currency} if $profile->{currency};
      }
    }
    $info{ $stock, 'currency' }          = $currency;
    $info{ $stock, 'currency_set_by_fq' } = 1;

    $info{ $stock, 'success' } = 1;

  }

  return wantarray() ? %info : \%info;

}

1;

__END__

=head1 NAME

Finance::Quote::Finnhub - Obtain quotes from https://finnhub.io

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new('Finnhub', finnhub => {API_KEY => 'your-finnhub-api-key'});

    %info = $q->fetch('finnhub', 'AAPL', 'MSFT');

=head1 DESCRIPTION

This module fetches information from L<https://finnhub.io>.

This module is loaded by default on a Finance::Quote object. It's also possible
to load it explicitly by placing "Finnhub" in the argument list to
Finance::Quote->new().

This module provides the "finnhub", "usa", "nyse", and "nasdaq" fetch methods.

=head1 API_KEY

L<https://finnhub.io> requires users to register and obtain an API key (token).
A free key is available with no credit card and is intended for personal,
non-professional use.

The API key may be set by either providing a module specific hash to
Finance::Quote->new as in the above example, or by setting the environment
variable FINNHUB_API_KEY.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::Finnhub:
symbol, name, last, open, high, low, close, net, p_change, date, isodate,
currency, method.

=head1 CAVEATS

The free Finnhub tier covers US listed equities, ETFs, forex, and
cryptocurrency. The trade date is derived from the last trade timestamp
returned by the quote endpoint, interpreted in the local timezone.

The trading currency and company name are obtained from the company profile
endpoint, which covers listed companies but not ETFs or other instruments.
When no currency is reported the price is assumed to be in USD, consistent
with the free tier's US focus.

=cut
