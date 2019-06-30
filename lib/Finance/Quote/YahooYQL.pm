#!/usr/bin/perl -w

#    This module is based on the Finance::Quote::YahooJSON. It uses
#    the Yahoo Query Language interface to retrieve quotes.
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

package Finance::Quote::YahooYQL;

require 5.005;

use strict;
use JSON qw( decode_json );
use vars qw($VERSION $YIND_URL_HEAD $YIND_URL_TAIL);
require LWP::Protocol::https;
use HTML::TableExtract;
use Time::Piece;

# VERSION

# TODO: for now we issue one request per quote. we should group requests as follows:
# https://query.yahooapis.com/v1/public/yql?q=select%20*%20from%20yahoo.finance.quotes%20where%20symbol%20in%20(%22YHOO%22%2C%22AAPL%22%2C%22GOOG%22%2C%22MSFT%22)&format=json&diagnostics=true&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys&callback=

my $YIND_URL_HEAD =
    "https://query.yahooapis.com/v1/public/yql?q=".
    "select%20*%20from%20yahoo.finance.quotes%20where%20symbol%20in%20(%22";
my $YIND_URL_TAIL =
    "%22)&format=json&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys";

sub methods {
    return ( yahoo_yql => \&yahoo_yql, );
}
{
    my @labels = qw/name last date isodate p_change open high low close
        volume currency method exchange type/;

    sub labels {
        return ( yahoo_yql => \@labels, );
    }
}

sub yahoo_yql {

    my $quoter = shift;
    my @stocks = @_;
    my ( %info, $reply, $url, $te, $ts, $row, @cells, $ce );
    my ( $my_date, $my_last, $my_p_change, $my_volume, $my_high, $my_low,
         $my_open );
    my $ua = $quoter->user_agent();
    $ua->ssl_opts( verify_hostname => 0 );

    foreach my $stocks (@stocks) {

        $url   = $YIND_URL_HEAD . $stocks . $YIND_URL_TAIL;
        $reply = $ua->get($url);
        my $code    = $reply->code;
        my $desc    = HTTP::Status::status_message($code);
        my $headers = $reply->headers_as_string;
        my $body    = $reply->content;

        #Response variables available:
        #Response code: 			$code
        #Response description: 	                $desc
        #HTTP Headers:				$headers
        #Response body				$body

        $info{ $stocks, "symbol" } = $stocks;

        if ( $code == 200 ) {

            #HTTP_Response succeeded - parse the data
            my $json_data = JSON::decode_json $body;

            #use DDP; p $json_data;

            my $json_data_count = $json_data->{'query'}{'count'};

            if ( $json_data_count != 1 ) {
                $info{ $stocks, "success" } = 0;
                $info{ $stocks, "errormsg" } =
                    "Error retrieving quote for $stocks - no listing for this name found.".
                    " Please check scrip name and the two letter extension (if any)";

            }
            else {

                my $json_resources = $json_data->{'query'}{'results'}{'quote'};
                my $json_symbol    = $json_resources->{'Symbol'};
                my $json_volume    = $json_resources->{'Volume'};
                my $json_timestamp = $json_resources->{'LastTradeDate'};
                my $json_name      = $json_resources->{'Name'} || '';
                my $json_price     = $json_resources->{'LastTradePriceOnly'};
                my $json_currency  = $json_resources->{'Currency'};
                my $json_exchange  = $json_resources->{'StockExchange'};

                $info{ $stocks, "success" }  = 1;
                $info{ $stocks, "exchange" } = $json_exchange;
                $info{ $stocks, "method" }   = "yahoo_yql";
                $info{ $stocks, "name" }   = $stocks . ' (' . $json_name . ')';
                $info{ $stocks, "type" }   = "Unsupported";
                $info{ $stocks, "last" }   = $json_price;
                $info{ $stocks, "volume" } = $json_volume;
                $info{ $stocks, "currency" } = $json_currency;
                if (    $json_timestamp
                     && $json_timestamp =~ m|(\d+)/(\d+)/(\d+)| )
                {
                    $info{ $stocks, "isodate" } =
                        join( '-',
                              sprintf( '%02d', $2 ),
                              sprintf( '%02d', $1 ), $3 );
                    $my_date = $info{ $stocks, "isodate" } . '.';
                    $my_date =~ s/\-/\./g;
                }

                $quoter->store_date( \%info, $stocks,
                                   { eurodate => $my_date, date => $my_date } );

            }
        }

        #HTTP request fail
        else {
            $info{ $stocks, "success" } = 0;
            $info{ $stocks, "errormsg" } =
                "Error retrieving quote for $stocks. Attempt to fetch the URL $url resulted in HTTP response $code ($desc)";
        }

    }

    return wantarray() ? %info : \%info;
    return \%info;
}

1;

=head1 NAME

Finance::Quote::YahooYQL - Obtain quotes from Yahoo Finance through YQL call

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("yahoo_yql","AAPL");

=head1 DESCRIPTION

This module fetches information from YQL as JSON

This module is loaded by default on a Finance::Quote object. It's
also possible to load it explicity by placing "YahooYQL" in the argument
list to Finance::Quote->new().

This module provides the "yahoo_yql" fetch method.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::YahooYQL :
name, last, isodate, volume, method, exchange, currency.

=head1 SEE ALSO

=cut
