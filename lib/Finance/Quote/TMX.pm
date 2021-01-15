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

package Finance::Quote::TMX;

use strict;
use warnings;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use HTTP::Request;
use LWP::UserAgent;
use JSON qw( decode_json encode_json );
use String::Util qw(trim);

# VERSION

our @labels = qw/name cap year_range currency exchange symbol ask bid high last low open close isodate date/;

sub labels {
  return ( tmx => \@labels );
}

sub methods {
  return ( tmx    => \&tmx,
           canada => \&tmx );
}

sub tmx {
  my $quoter  = shift;
  my @symbols = @_;
  my $ua      = $quoter->user_agent();
  my %info;

  foreach my $symbol (@_) {
    eval {
      my $url     = 'https://app-money.tmx.com/graphql';
      my $header  = ["accept"           =>           "*/*",
                     "accept-language"  => "en-US,en;q=0.9",
                     "authorization"    => "",
                     "content-type"     => "application/json",
                     "locale"           => "en",
                     "sec-ch-ua"        => "\"Google Chrome\";v=\"87\", \" Not;A Brand\";v=\"99\", \"Chromium\";v=\"87\"",
                     "sec-ch-ua-mobile" => "?0",
                     "sec-fetch-dest"   => "empty",
                     "sec-fetch-mode"   => "cors",
                     "sec-fetch-site"   => "same-site"];
      my $body   = "{\"operationName\":\"getQuoteBySymbol\",\"variables\":{\"symbol\":\"$symbol\",\"locale\":\"en\"},\"query\":\"query getQuoteBySymbol(\$symbol: String, \$locale: String) {\\n  getQuoteBySymbol(symbol: \$symbol, locale: \$locale) {\\n    symbol\\n    name\\n    price\\n    priceChange\\n    percentChange\\n    exchangeName\\n    exShortName\\n    exchangeCode\\n    marketPlace\\n    sector\\n    industry\\n    volume\\n    openPrice\\n    dayHigh\\n    dayLow\\n    MarketCap\\n    MarketCapAllClasses\\n    peRatio\\n    prevClose\\n    dividendFrequency\\n    dividendYield\\n    dividendAmount\\n    dividendCurrency\\n    beta\\n    eps\\n    exDividendDate\\n    shortDescription\\n    longDescription\\n    website\\n    email\\n    phoneNumber\\n    fullAddress\\n    employees\\n    shareOutStanding\\n    totalDebtToEquity\\n    totalSharesOutStanding\\n    sharesESCROW\\n    vwap\\n    dividendPayDate\\n    weeks52high\\n    weeks52low\\n    alpha\\n    averageVolume10D\\n    averageVolume30D\\n    averageVolume50D\\n    priceToBook\\n    priceToCashFlow\\n    returnOnEquity\\n    returnOnAssets\\n    day21MovingAvg\\n    day50MovingAvg\\n    day200MovingAvg\\n    dividend3Years\\n    dividend5Years\\n    datatype\\n    __typename\\n  }\\n}\\n\"}";

      
      my $request = HTTP::Request->new('POST', $url, $header, $body);
      $request->header("referrer"       => "https://money.tmx.com/",
                       "referrerPolicy" => "strict-origin-when-cross-origin",
                       "mode"           =>  "cors");

      my $reply     = $ua->request($request);
      
      ### Search   : $url, $reply->code
      ### reply    : $reply->content
      
      my $data      = decode_json $reply->content;

      die "Unexpected result" unless exists $data->{data}
                              and    exists $data->{data}->{getQuoteBySymbol};
      
      $data = $data->{data}->{getQuoteBySymbol};

      die "Unexpected symbol" unless lc($data->{symbol}) eq lc($symbol);

      ### data     : $data

      $info{$symbol, 'name'}       = $data->{name};
      $info{$symbol, 'exchange'}   = $data->{exchangeName};
      $info{$symbol, 'volume'}     = $data->{volume};
      $info{$symbol, 'open'}       = $data->{openPrice};
      $info{$symbol, 'high'}       = $data->{dayHigh};
      $info{$symbol, 'low'}        = $data->{dayLow};
      $info{$symbol, 'cap'}        = $data->{MarketCap};
      $info{$symbol, 'close'}      = $data->{prevClose};
      $info{$symbol, 'year_range'} = $data->{weeks52low} . ' - ' . $data->{weeks52high};
      $info{$symbol, 'symbol'}     = $data->{symbol};

      $info{$symbol, 'success'} = 1;
    };
    
    if ($@) {
      my $error = "TMX failed: $@";
      $info{$symbol, 'success'}  = 0;
      $info{$symbol, 'errormsg'} = trim($error);
    }
  }

  return wantarray() ? %info : \%info;
}

1;

=head1 NAME

Finance::Quote::TSX - Obtain quotes from the Toronto Stock Exchange 
(https://money.tmx.com)

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %stockinfo = $q->fetch('tmx','NT-T');   # Only query TMX
    %stockinfo = $q->fetch('canada','NT');  # Failover to other Canadian sources

=head1 DESCRIPTION

This module obtains information from the Toronto Stock Exchange,
https://money.tmx.com.

This module is loaded by default on a Finance::Quote object. It's also
possible to load it explicitly by placing 'TMX' in the argument list to
Finance::Quote->new().

=head1 LABELS RETURNED

The following labels are returned by Finance::Quote::TMX: name,
exchange, volume, open, high, low, cap, close, year_range, symbol

=head1 TERMS & CONDITIONS

Use of money.tmx.com is governed by any terms & conditions of that
site and its data provider quotemedia.com.

Finance::Quote is released under the GNU General Public License, version 2,
which explicitly carries a "No Warranty" clause.

=cut
