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

package Finance::Quote::WorldTrading;

require 5.005;

our $VERSION = '1.00'; # VERSION

use strict;
use JSON qw( decode_json );
use HTTP::Request::Common;

my $WORLDTRADING_URL =
    'https://www.worldtradingdata.com/api/v1/stock?output=json';
my $WORLDTRADING_API_KEY = $ENV{'WORLDTRADING_API_KEY'};

my %currencies_by_suffix =
    ( '.TO' => 'CAD', '.BR' => 'EUR', '.DE' => 'EUR', '.L' => 'GBP', '.SA' => 'BRL', );

sub methods {
    return ( worldtrading => \&worldtrading, );

    our @labels = qw/date isodate open high low close volume last/;

    sub labels {
        return ( worldtrading => \@labels, );
    }
}

sub worldtrading {
    my $quoter = shift;

    my @stocks = @_;
    my $quantity = @stocks;
    my ( %info, $reply, $url );
    my $ua = $quoter->user_agent();

    foreach my $stock (@stocks) {

        if ( !defined $WORLDTRADING_API_KEY ) {
            $info{ $stock, 'success' } = 0;
            $info{ $stock, 'errormsg' } =
                'Expected WORLDTRADING_API_KEY to be set; get an API key at https://www.worldtradingdata.com/';
            next;
        }

        $url =
              $WORLDTRADING_URL
            . '&api_token='
            . $WORLDTRADING_API_KEY
            . '&symbol='
            . $stock;
        $reply = $ua->request( GET $url);

        my $code = $reply->code;
        my $desc = HTTP::Status::status_message($code);
        my $body = $reply->content;

        # A Bad API Token will return {"message":"Invalid API Key."}
        # Stock not found returns
        # {"Message":"Error! The requested stock(s) could not be found."}
        my $json_data = JSON::decode_json $body;
        if ( !$json_data || $json_data->{'Message'} ||
        $json_data->{'message'} ) {
            $info{ $stock, 'success' } = 0;
            $info{ $stock, 'errormsg' } =
                $json_data->{'Message'} || $json_data->{'message'};
            next;
        }

        my $symbols_returned = $json_data->{'symbols_returned'};
        if ( $symbols_returned != 1 ) {
            $info{ $stock, 'success' } = 0;
            $info{ $stock, 'errormsg' } = "json_data doesn't contain data for stock";
            next;
            }

        my %sd = %{ $json_data->{'data'}[0] };

        # %sd holds data as
        #  {
        #     'price_open'       151.5400,
        #     'day_high'         151.5900,
        #     'day_low'          151.5300,
        #     'price'            151.5900,
        #     'symbol'           AAPL,
        #     'currency'         USD,
        #     'last_trade_time'  2018-06-19 11:08:32,
        #     'volume'           57620
        # }

        $info{ $stock, 'success' }  = 1;
        $info{ $stock, 'symbol' }   = $sd{'symbol'};
        $info{ $stock, 'open' }     = $sd{'price_open'};
        $info{ $stock, 'close' }    = $sd{'price'};
        $info{ $stock, 'last' }     = $sd{'price'};
        $info{ $stock, 'high' }     = $sd{'day_high'};
        $info{ $stock, 'low' }      = $sd{'day_low'};
        $info{ $stock, 'volume' }   = $sd{'volume'};
        $info{ $stock, 'currency' } = $sd{'currency'};
        $info{ $stock, 'method' }   = 'worldtrading';
        my $last_trade_time         = $sd{'last_trade_time'};
        my $isodate                 = substr( $last_trade_time, 0, 10 );
        $quoter->store_date( \%info, $stock, { isodate => $isodate } );
        $quantity--;
        select(undef, undef, undef, .7) if ($quantity);
    }

    return wantarray() ? %info : \%info;
}
