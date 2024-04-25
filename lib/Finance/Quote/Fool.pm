#!/usr/bin/perl -w
# vi: set noai ts=2 sw=2 ic showmode showmatch: 
#    This module was rewritten in June 2019 based on the 
#    Finance::Quote::IEXCloud.pm module and prior versions of Fool.pm
#    that carried the following copyrights:
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@cpan.org>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#    Copyright (C) 2001, Tobias Vancura <tvancura@altavista.net>
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

package Finance::Quote::Fool;

use strict;
use HTTP::Request::Common;
use HTML::TreeBuilder;
use JSON qw( decode_json );
use Text::Template;
use Encode qw(decode);

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

# VERSION

my $SEARCHURL = Text::Template->new(TYPE => 'STRING', SOURCE => 'https://api.fool.com/quotes/v4/instruments/search/?maxResults=10&apikey=public&domain=fool.com&query={$symbol}');

my $QUOTEURL = Text::Template->new(TYPE => 'STRING', SOURCE => 'https://www.fool.com/quote/{$lcexchange}/{$lcsymbol}/');

sub methods { 
  return ( fool   => \&fool,
           usa    => \&fool,
           nasdaq => \&fool,
           nyse   => \&fool);
}

my @labels = qw/date isodate open high low close volume last/;
sub labels {
  return ( iexcloud => \@labels, );
}

sub fool {
    my $quoter = shift;
    my @stocks = @_;
    
    my (%info, $symbol, $url, $reply, $code, $desc, $body);
    my ($json_data, $instrumentID, $exchange, $tree );
    my %mnames = (jan => 1, feb => 2, mar => 3, apr => 4, may => 5, jun => 6,
      jul => 7, aug => 8, sep => 9, oct =>10, nov =>11, dec =>12);
    my $ua = $quoter->user_agent();
    $ua->agent('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.0.0 Safari/537.36');
    
    my $quantity = @stocks;

    ### Stocks: @stocks

    foreach my $symbol (@stocks) {

        # Get the JSON with possible matches
        $url   = $SEARCHURL->fill_in(HASH => {symbol => $symbol});
        ### url: $url
        $reply = $ua->request( GET $url);
        $code  = $reply->code;
        $desc  = HTTP::Status::status_message($code);
        $body  = decode('UTF-8', $reply->content);

       ### Reply: $reply
  
        if ($code != 200) {
            $info{ $symbol, 'success' } = 0;
            $info{ $symbol, 'errormsg' } = $desc;
            next;
        }

				### Body: $body

        # Parse the JSON
        eval {$json_data = JSON::decode_json $body};
        if ($@) {
            $info{ $symbol, 'success' } = 0;
            $info{ $symbol, 'errormsg' } = $@;
        }

        # The JSON returned may return information for multiple
        # securities
        #  {
        #    "ResultsFound": true,
        #    "SearchResults": [
        #      {
        #        "IndexedDate": "2023-01-14T02:44:40+00:00",
        #        "InstrumentId": 203983,
        #        "Symbol": "IBM",
        #        "Exchange": "NYSE",
        #        "Name": "International Business Machines",
        #        "AssetClass": "stock",
        #        "Popularity": 0,
        #        "Country": "US",
        #        "Sector": "Information Technology",
        #        "Industry": "IT Services",
        #        "IgnoreInSearch": false,
        #        "Relevance": 86.37764
        #      },
        #      {
        #        "IndexedDate": "2023-01-14T02:44:45+00:00",
        #        "InstrumentId": 270916,
        #        "Symbol": "IBM",
        #        "Exchange": "LSE",
        #        "Name": "International Business Machines",
        #        "AssetClass": "stock",
        #        "Popularity": 0,
        #        "Country": "US",
        #        "Sector": "Information Technology",
        #        "Industry": "IT Services",
        #        "IgnoreInSearch": false,
        #        "Relevance": 80.79494
        #      }
        #    ]
        #  }

        my $searchresults = $json_data->{'SearchResults'};

        # Loop through the array looking for a match for Symbol and
        # US Exchanges
        # In the future, symbols supplied can be "LSE:IBM". Will match
        # Symbol and Exchange.

        foreach my $item( @$searchresults ) {
          if ( $item->{'Symbol'} eq $symbol &&
               $item->{'Exchange'} =~ /NYSE|NASDAQ|OTC/ ) {
                 $instrumentID = $item->{'InstrumentId'};
                 $exchange = $item->{'Exchange'};
                 last;
               }
        }

        # If instrumentID is not set return error
        unless ($instrumentID) {
          $info{ $symbol, "success" } = 0;
          $info{ $symbol, "errormsg" } = "Stock symbol not found";
          next;
        }

        # Create QUOTE URL 
        $url   = $QUOTEURL->fill_in(HASH => {lcsymbol => lc($symbol), lcexchange => lc($exchange)});

        ### [<now>] Quote URL: $url
        $reply = $ua->request( GET $url);
        $code  = $reply->code;
        $desc  = HTTP::Status::status_message($code);
        $body  = decode('UTF-8', $reply->content);

        ### [<now>] Reply: $reply
  
        if ($code != 200) {
            $info{ $symbol, 'success' } = 0;
            $info{ $symbol, 'errormsg' } = $desc;
            next;
        }

				### [<now>] Body: $body

        $tree = HTML::TreeBuilder->new;
        $tree->ignore_unknown(0);
        unless ($tree->parse_content($body)) {
            $info{ $symbol, "success" } = 0;
            $info{ $symbol, "errormsg" } =
              "Cannot parse HTML from $url";
            next;
        }

        ### [<now>] Tree: $tree

        # Date is in a div tag
        # <div class="text-xs text-gray-700">Price as of April 22, 2024, 4:00 p.m. ET</div>
        my $datetag = $tree->look_down(_tag => 'div', class => 'text-xs text-gray-700');
        my @datestring = $datetag->content_list();
        ### [<now>] Datestring Array: @datestring

        my ($month,$day,$year) = ($datestring[0] =~
          /Price as of ([a-zA-Z]+) (\d+), (\d\d\d\d),/);
        $month = $mnames{lc(substr($month,0,3))};

        my $quotecard = $tree->look_down(_tag => 'quote_card');
        unless ($quotecard) {
          $info{ $symbol, "success" } = 0;
          $info{ $symbol, "errormsg" } = "Cannot find quote_card in $url";
          next;
        }

        ### [<now>] quotecard: $quotecard

        my $last = $quotecard->{':current-price'};
        ### [<now>] Current price: $last
        my $high = $quotecard->{':daily-high'};
        my $low = $quotecard->{':daily-low'};
        my $open = $quotecard->{':open'};
        (my $volume = $quotecard->{'volume'}) =~ s/,//g;
        my $currency = $quotecard->{'currency-code'};

        $info{ $symbol, 'last'} = $last;
        $info{ $symbol, 'open'} = $open;
        $info{ $symbol, 'high'} = $high;
        $info{ $symbol, 'low'} = $low;
        $info{ $symbol, 'volume'} = $volume;
        $info{ $symbol, 'currency' } = $currency;
        $quoter->store_date(\%info, $symbol, {month => $month, day => $day, year => $year});   
        $info{ $symbol, 'symbol' } = $symbol;
        $info{ $symbol, 'method' } = 'fool';
        $info{ $symbol, 'success' } = 1;

    }

    return wantarray() ? %info : \%info;
}

1;

=head1 NAME

Finance::Quote::Fool - Obtain quotes from the Motley Fool web site.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %stockinfo = $q->fetch('fool','GE', 'INTC');

=head1 DESCRIPTION

This module obtains information from the Motley Fool website
(http://caps.fool.com). The site provides date from NASDAQ, NYSE and AMEX.

This module is loaded by default on a Finance::Quote object.  It's
also possible to load it explicitly by placing "Fool" in the argument
list to Finance::Quote->new().

Information returned by this module is governed by the Motley Fool's terms and
conditions.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::Fool:
symbol, open, high, low, volume, last, currency, method.

=head1 SEE ALSO

Motley Fool, http://www.fool.com

Finance::Quote.

=cut
