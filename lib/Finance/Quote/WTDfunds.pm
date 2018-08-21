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

package Finance::Quote::WTDfunds;

require 5.005;

our $VERSION = '1.00'; # VERSION

use strict;
use JSON qw( decode_json );
#use POSIX qw(strftime);
use HTTP::Request::Common;

my $WORLDTRADING_URL =
    'https://www.worldtradingdata.com/api/v1/mutualfund?output=json';
my $WORLDTRADING_API_KEY = $ENV{'WORLDTRADING_API_KEY'};

my %currencies_by_suffix =
    ( '.TO' => 'CAD', '.BR' => 'EUR', '.DE' => 'EUR', '.L' => 'GBP', '.SA' => 'BRL', );

sub methods {
    return ( wtdfunds => \&wtdfunds, );

    our @labels = qw/date isodate open high low close volume last/;

    sub labels {
        return ( wtdfunds => \@labels, );
    }
}

sub wtdfunds {
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

        # %sd for WorldTradingData's mutual funds holds data as
        # {
        #    'symbol'                 AAAAX,
        #    'name'                   DWS RREEF Real Assets Fund - Class A,
        #    'price'                  9.61,
        #    'close_yesterday'        9.61,
        #    'return_ytd'             1.42,
        #    'net_assets'             98267850,
        #    'change_asset_value'     0.05,
        #    'change_pct'             0.52,
        #    'yield_pct'              1.39,
        #    'return_day'             0.52,
        #    'return_1week'           -0.41,
        #    'return_4week'           -0.66,
        #    'return_13week'          3.36,
        #    'return_52week'          8.41,
        #    'return_156week'         3.97,
        #    'return_260week'         2.76,
        #    'income_dividend'        0.09,
        #    'income_dividend_date'   2018-06-22 16:00:00,
        #    'capital_gain'           0.05,
        #    'expense_ratio'          1.22
        # }

        $info{ $stock, 'success' }  = 1;
        $info{ $stock, 'symbol' }   = $sd{'symbol'};
        $info{ $stock, 'close' }    = $sd{'price'};
        $info{ $stock, 'last' }     = $sd{'price'};
        $info{ $stock, 'high' }     = $sd{'price'};
        $info{ $stock, 'low' }      = $sd{'price'};
        $info{ $stock, 'volume' }   = $sd{'net_assets'};
        $info{ $stock, 'currency' } = 'USD';
        $info{ $stock, 'currency' } = $sd{'currency'} if ($sd{'currency'});
        $info{ $stock, 'method' }   = 'wtdfunds';
        # Kludge for date since it's not returned in the JSON data
        # my $isodate                 = strftime "%Y-%m-%d", localtime;
        $quoter->store_date( \%info, $stock, { today => 1 } );
        $quantity--;
        select(undef, undef, undef, .7) if ($quantity);
    }

    return wantarray() ? %info : \%info;
}
