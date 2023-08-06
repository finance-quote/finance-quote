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
use Readonly;
Readonly my $DEBUG => $ENV{DEBUG};
use if $DEBUG, 'Smart::Comments';

use HTTP::Request;
use LWP::UserAgent;
use JSON qw( decode_json encode_json );
use String::Util qw(trim);

# VERSION

our @labels = qw/currency name exchange volume open high low cap close year_range last p_change symbol isodate date/;

sub features() {
    return {'description' => 'Fetch quotes from the Toronto Stock Exchange'};
}

sub labels {
  return ( tmx => \@labels );
}

sub methods {
  return ( tmx    => \&tmx,
           tsx => \&tmx,
           canada => \&tmx );
}

sub tmx {
  my $quoter  = shift;
  my @symbols = @_;
  my $ua      = $quoter->user_agent();
  my %info;

  foreach my $symbol (@symbols) {
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
      my $body   = "{\"operationName\":\"getQuoteBySymbol\",\"variables\":{\"symbol\":\"$symbol\",\"locale\":\"en\"},\"query\":\"query getQuoteBySymbol(\$symbol: String, \$locale: String) {\\n getQuoteBySymbol(symbol: \$symbol, locale: \$locale) {\\n symbol\\n name\\n price\\n percentChange\\n exchangeName\\n volume\\n openPrice\\n dayHigh\\n dayLow\\n MarketCap\\n prevClose\\n weeks52high\\n weeks52low\\n }\\n}\\n\"}";

      
      my $request = HTTP::Request->new('POST', $url, $header, $body);
      $request->header("referrer"       => "https://money.tmx.com/",
                       "referrerPolicy" => "strict-origin-when-cross-origin",
                       "mode"           =>  "cors");

      my $reply     = $ua->request($request);
      if (! $reply->is_success) {
        $info{$symbol, 'errormsg'} = 'Failed to connect with TMX website';
        $info{$symbol, 'success'}  = 0;
        return;
      }
      ### Search   : $url, $reply->code
      ### reply    : $reply->content
      
      my $data      = decode_json $reply->content;
      if (exists $data->{errors}) {
            $info{$symbol, 'errormsg'} = $data->{errors}[0]->{message};
            $info{$symbol, 'success'}  = 0;
            return;
      }

      $data = $data->{data}->{getQuoteBySymbol};
      if (lc($data->{symbol}) ne lc($symbol)) {
            $info{$symbol, 'errormsg'} = "returned symbol was not correct for $symbol";
            $info{$symbol, 'success'}  = 0;
            return
      }

      if ( $symbol =~ /:us/ix ) {
            $info{$symbol, 'currency'} = 'USD'; }
      else {$info{$symbol, 'currency'} = 'CAD'}

      $info{$symbol, 'name'}       = $data->{name};
      $info{$symbol, 'exchange'}   = $data->{exchangeName};
      $info{$symbol, 'volume'}     = $data->{volume};
      $info{$symbol, 'open'}       = $data->{openPrice};
      $info{$symbol, 'high'}       = $data->{dayHigh};
      $info{$symbol, 'low'}        = $data->{dayLow};
      $info{$symbol, 'cap'}        = $data->{MarketCap};
      $info{$symbol, 'close'}      = $data->{prevClose};
      $info{$symbol, 'year_range'} = $data->{weeks52low} . ' - ' . $data->{weeks52high};
      $info{$symbol, 'last'}       = $data->{price};
      $info{$symbol, 'symbol'}     = $data->{symbol};
      $info{$symbol, 'p_change'}   = $data->{percentChange};
      $quoter->store_date(\%info, $symbol, {today => 1});

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

Finance::Quote::TMX - Obtain quotes from the Toronto Stock Exchange 
(https://money.tmx.com)

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %stockinfo = $q->fetch('tmx','NT-T');   # Only query TMX
    %stockinfo = $q->fetch('canada','NT');  # Failover to other Canadian sources
y
=head1 DESCRIPTION

This module obtains information from the Toronto Stock Exchange,
https://money.tmx.com.

This module is loaded by default on a Finance::Quote object. It's also
possible to load it explicitly by placing 'TMX' in the argument list to
Finance::Quote->new().

=head1 LABELS RETURNED

The following labels are returned by Finance::Quote::TMX: name,
exchange, volume, open, high, low, cap, close, year_range, symbol, last, p_change

=head1 TERMS & CONDITIONS

Use of money.tmx.com is governed by any terms & conditions of that
site and its data provider quotemedia.com.

Finance::Quote is released under the GNU General Public License, version 2,
which explicitly carries a "No Warranty" clause.

=cut
