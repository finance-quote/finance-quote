#!/usr/bin/perl -w
#    This module is based on the Finance::Quote::yahooJSON module
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
#    Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
#    02111-1307, USA

package Finance::Quote::AlphaVantage;

require 5.005;

# VERSION

use strict;
use JSON qw( decode_json );
use HTTP::Request::Common;

my $ALPHAVANTAGE_URL =
    'https://www.alphavantage.co/query?function=TIME_SERIES_DAILY&outputsize=compact&datatype=json';
my $ALPHAVANTAGE_API_KEY = $ENV{'ALPHAVANTAGE_API_KEY'};

my %currencies_by_suffix = ( '.BR' => 'EUR', '.L' => 'GBP', );

sub methods {
    return ( alphavantage => \&alphavantage, );

    our @labels = qw/date isodate open high low close volume last/;

    sub labels {
        return ( alphavantage => \@labels, );
    }
}

sub alphavantage {
    my $quoter = shift;
    my @stocks = @_;
    my ( %info, $reply, $url );
    my $ua = $quoter->user_agent();

    foreach my $stock (@stocks) {

        if ( !defined $ALPHAVANTAGE_API_KEY ) {
            $info{ $stock, 'success' } = 0;
            $info{ $stock, 'errormsg' } =
                'Expected ALPHAVANTAGE_API_KEY to be set; get an API key at https://www.alphavantage.co';
            next;
        }

        $url =
              $ALPHAVANTAGE_URL
            . '&apikey='
            . $ALPHAVANTAGE_API_KEY
            . '&symbol='
            . $stock;
        $reply = $ua->request( GET $url);

        my $code = $reply->code;
        my $desc = HTTP::Status::status_message($code);
        my $body = $reply->content;

        my $json_data = JSON::decode_json $body;
        if ( !$json_data || $json_data->{'Error Message'} ) {
            $info{ $stock, 'success' } = 0;
            $info{ $stock, 'errormsg' } =
                $json_data->{'Error Message'} || $json_data->{'Information'};
            next;
        }

        my $last_refresh = $json_data->{'Meta Data'}->{'3. Last Refreshed'};
        my $isodate = substr( $last_refresh, 0, 10 );
        my %ts = %{ $json_data->{'Time Series (Daily)'}->{$last_refresh} };
        if ( !%ts ) {
            $info{ $stock, 'success' }  = 0;
            $info{ $stock, 'errormsg' } = 'Could not extract Time Series data';
            next;
        }

        # %ts holds data as
        #  {
        #     '1. open'     151.5400,
        #     '2. high'     151.5900,
        #     '3. low'      151.5300,
        #     '4. close'    151.5900,
        #     '5. volume'   57620
        # }

        $info{ $stock, 'success' } = 1;
        $info{ $stock, 'symbol' }  = $json_data->{'Meta Data'}->{'2. Symbol'};
        $info{ $stock, 'open' }    = $ts{'1. open'};
        $info{ $stock, 'close' }   = $ts{'4. close'};
        $info{ $stock, 'last' }    = $ts{'4. close'};
        $info{ $stock, 'high' }    = $ts{'2. high'};
        $info{ $stock, 'low' }     = $ts{'3. low'};
        $info{ $stock, 'volume' }  = $ts{'5. volume'};
        $info{ $stock, 'method' }  = 'alphavantage';
        $quoter->store_date( \%info, $stock, { isodate => $isodate } );
        # deduce currency
        if ($stock =~ /\.(.*)/) {
                my $suffix = $1;
                $info{ $stock, 'currency' } = $currencies_by_suffix{$suffix}
                    if ( $currencies_by_suffix{$suffix} );
            } else {
                $info{ $stock, 'currency' } = 'USD';
            }
    }

    return wantarray() ? %info : \%info;
}
