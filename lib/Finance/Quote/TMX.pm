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
      my $url       = 'https://app.quotemedia.com/datatool/getEnhancedQuotes.json?timezone=true&afterhours=true&premarket=true&currencyInd=true&countryInd=true&marketstatus=true&token=a93722d6c03cbab64459d578082f72c38b7c9157b52f056353c3c4f43324f0cb';
      my $request   = HTTP::Request->new(GET => $url . '&symbols=' . $symbol);

      $request->header('authority'        => 'app.quotemedia.com');
      $request->header('sec-ch-ua'        => '"Google Chrome";v="87", " Not;A Brand";v="99", "Chromium";v="87"');
      $request->header('accept'           => '*/*');
      $request->header('accept-language'  => 'en');
      $request->header('sec-ch-ua-mobile' => '?0');
      $request->header('user-agent'       => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 11_1_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.88 Safari/537.36');
      $request->header('origin'           => 'https://money.tmx.com');
      $request->header('sec-fetch-site'   => 'cross-site');
      $request->header('sec-fetch-mode'   => 'cors');
      $request->header('sec-fetch-dest'   => 'empty');
      $request->header('referer'          => 'https://money.tmx.com/');

      my $reply     = $ua->request($request);
      
      ### Search   : $url, $reply->code
      ### reply    : $reply->content
      
      my $data      = decode_json $reply->content;

      die "Unexpected result" unless exists $data->{results}
                              and    exists $data->{results}->{quote}
                              and    @{$data->{results}->{quote}} == 1;

      $data = $data->{results}->{quote}->[0];
      
      die "Symbol not found" unless $data->{key}->{exchange} ne '';

      ### data     : $data

      $info{$symbol, 'name'}       = $data->{equityinfo}->{longname};
      $info{$symbol, 'cap'}        = $data->{fundamental}->{marketcap};
      $info{$symbol, 'year_range'} = $data->{fundamental}->{week52low}->{content} . ' - ' . $data->{fundamental}->{week52high}->{content};
      $info{$symbol, 'currency'}   = $data->{key}->{currency};
      $info{$symbol, 'exchange'}   = $data->{key}->{exLgName};
      $info{$symbol, 'symbol'}     = $data->{key}->{symbol};
      $info{$symbol, 'ask'}        = $data->{pricedata}->{ask};
      $info{$symbol, 'bid'}        = $data->{pricedata}->{bid};
      $info{$symbol, 'high'}       = $data->{pricedata}->{high};
      $info{$symbol, 'last'}       = $data->{pricedata}->{last};
      $info{$symbol, 'low'}        = $data->{pricedata}->{low};
      $info{$symbol, 'open'}       = $data->{pricedata}->{open};
      $info{$symbol, 'close'}      = $data->{pricedata}->{prevclose};

      $quoter->store_date(\%info, $symbol, {isodate => $data->{pricedata}->{lasttradedatetime}});

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

The following labels are returned by Finance::Quote::TMX: name, cap,
year_range, currency, exchange, symbol, ask, bid, high, last, low, open,
close, isodate, date

=head1 TERMS & CONDITIONS

Use of money.tmx.com is governed by any terms & conditions of that
site and its data provider quotemedia.com.

Finance::Quote is released under the GNU General Public License, version 2,
which explicitly carries a "No Warranty" clause.

=cut
