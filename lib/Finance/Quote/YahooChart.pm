#!/usr/bin/perl -w
#    This module is based on the Finance::Quote::YahooJSON module
#
#    The code has been writtem/modified by Kalpesh Patel to
#    retrieve stock information from Yahoo Finance Chart API call and 
#    parse through json
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

require 5.005;

use strict;

# Note that we use $ENV{} since it can be passed transparently through GNC to F::Q module

#-## For *nix, call GNC as follows:
#-##   DEBUG=1 YAHOO_CHART_EXTENDED=1 /usr/bin/gnucash <options1> <option2> ...

#-## For Windows, call GNC as follows:
#-##   set DEBUG=1 & YAHOO_CHART_EXTENDED=1 & "c:\Program Files (x86)\gnucash\bin\gnucash.exe" <options1> <option2> ...
#-##
#-## To unset an env variable in Windows, just leave out the value for the env variable. I. E., : 
#-##   set DEBUG=  & YAHOO ...
#-## 

use constant DEBUG => $ENV{DEBUG}; 
use if DEBUG, 'Smart::Comments', '###'; 
use Data::Dumper; 

package Finance::Quote::YahooChart;

use JSON qw( decode_json );
use vars qw($VERSION $YIND_URL_HEAD $YIND_URL_TAIL);
use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;
use Time::Piece;

# VERSION

my $endepoc = time(); # now in UNIX epoc seconds
my $startepoc = $endepoc - (7 * 24 * 60 * 60); # 7 days ago in UNIX epoc seconds

# https://query1.finance.yahoo.com/v8/finance/chart/AAPL?symbol=AAPL&period1=0&period2=9999999999&interval=1d&includePrePost=true&events=div%7Csplit
# Valid intervals: [1m, 2m, 5m, 15m, 30m, 60m, 90m, 1h, 1d, 5d, 1wk, 1mo, 3mo, 6mo, ytd, 1y, 2y, 5y, 10y, max]
my $YIND_URL_HEAD = 'https://query1.finance.yahoo.com/v8/finance/chart/';
my $YIND_URL_TAIL = '?interval=1d&period1=' . $startepoc . '&period2=' . $endepoc;

sub methods {
    return ( yahoo_chart => \&yahoo_chart,
    );
}
{
    my @labels = qw/date isodate volume currency method exchangeName instrumentType
        open high low close nav price adjclose/;

    sub labels {
        return ( yahoo_chart => \@labels,
        );
    }
}

sub yahoo_chart {

    my $quoter = shift;
    my @stocks = @_;
    my ( %info, $reply, $url, $te, $ts, $row, @cells, $ce );
    my ( $my_date, $amp_stocks );
    my $ua = $quoter->user_agent();

    foreach my $stocks (@stocks) {

        # Issue 202 - Fix symbols with Ampersand
        # Can also be written as
				# $amp_stocks = $stocks =~ s/&/%26/gr;
        ($amp_stocks = $stocks) =~ s/&/%26/g;

        $url   = $YIND_URL_HEAD . $amp_stocks . $YIND_URL_TAIL;

        ### [<now>]   url  : $url
        $reply = $ua->request( GET $url);
        ### [<now>] reply  : $reply

        my $code    = $reply->code;
        my $desc    = HTTP::Status::status_message($code);
        my $headers = $reply->headers_as_string;
        my $body    = $reply->content;

        #Response variables available:
        #Response code: 	$code
        #Response description: 	$desc
        #HTTP Headers:		$headers
        #Response body		$body

        $info{ $stocks, "symbol" } = $stocks;
        $info{ $stocks, "method" } = "yahoo_chart";
        $info{ $stocks, "success" } = 0;

        if ( $code == 200 ) {

            #HTTP_Response succeeded - parse the data
            my $json_info = JSON::decode_json $body;
            my $json_data = $json_info->{'chart'}{'result'}[0];

#            if (not defined $json_data->{'indicators'}{'quote'}) {
            if (defined $json_info->{'chart'}{'error'}) {

                $info{ $stocks, "errormsg" } = 
                    "Error retrieving quote for $stocks - no listing for this name found. Please check symbol and the two letter extension (if any).\n\
                     Received " . $json_info->{'chart'}{'error'} . " error.";

            }
            else {

                # instrumentType shows whether the stock is equity, index, currency, or commodity
                $info{ $stocks, 'type'} = $json_data->{'meta'}{'instrumentType'};
                $info{ $stocks, 'exchange'} = $json_data->{'meta'}{'exchangeName'};
                $info{ $stocks, 'currency'} = $json_data->{'meta'}{'currency'};

                my $timestamps = $json_data->{'timestamp'};

                if (not defined ($timestamps)) {
                    $info{ $stocks, "errormsg" } = 
                        "Error retrieving quote for $stocks - No historical pricing data found in the data returned by the API.";
                    return wantarray() ? %info : \%info;
                    return \%info;
                }

                my $tablerows = scalar (@{$timestamps});
                ### [<now>] table size received : $tablerows

                # if (not defined($json_data->{'indicators'}{'quote'}[0]{'close'}[$tablerows])) {
                while (($tablerows >= 0) and not defined ($json_data->{'indicators'}{'quote'}[0]{'close'}[$tablerows])) {
                    $tablerows -= 1;
                }
                ### [<now>] valid data row index : $tablerows

                if ($tablerows < 0) {
                    $info{ $stocks, "errormsg" } = 
                        "Error retrieving quote for $stocks - No valid pricing data row found in the data returned by the API.";
                    return wantarray() ? %info : \%info;
                    return \%info;
                }

                my $json_timestamp = $json_data->{'timestamp'}[$tablerows];

                if (defined ($ENV{YAHOO_CHART_EXTENDED})) {
                    for my $element (keys %{$json_data->{'meta'}}) {
                        if (not $element =~ m/(currentTradingPeriod|validRanges)/i) {
                            $info{ $stocks, $element } 
                                = $json_data->{'meta'}{$element};
                        }
                    }

                    for my $period (keys %{$json_data->{'meta'}{'currentTradingPeriod'}}) {
                        for my $attrib (keys %{$json_data->{'meta'}{'currentTradingPeriod'}{$period}}) {
                            if ($attrib =~ m/(start|end)/i) { 
                                $info{ $stocks, $period . '_trading_' . $attrib } 
                                    = localtime($json_data->{'meta'}{'currentTradingPeriod'}{$period}{$attrib})->strftime('%d.%m.%Y %H:%M:%S');
                            }
                            else {
                                $info{ $stocks, $period . '_trading_' . $attrib } 
                                    = $json_data->{'meta'}{'currentTradingPeriod'}{$period}{$attrib};   
                            }
                        }
                    }


                    $info{ $stocks, 'firstTradeDate' } 
                        = localtime ($info{ $stocks, 'firstTradeDate' })->strftime('%d.%m.%Y %H:%M:%S');
                    $info{ $stocks, 'regularMarketTime' }
                        = localtime ($info{ $stocks, 'regularMarketTime' })->strftime('%d.%m.%Y %H:%M:%S');
                }

                for my $prices (keys %{$json_data->{'indicators'}{'quote'}[0]}) {
                    $info{ $stocks, $prices } = $json_data->{'indicators'}{'quote'}[0]{$prices}[$tablerows];
                }

                for my $prices (keys %{$json_data->{'indicators'}{'adjclose'}[0]}) {
                    $info{ $stocks, $prices } = $json_data->{'indicators'}{'adjclose'}[0]{$prices}[$tablerows];
                }

                for my $prices (keys %{$json_data->{'indicators'}{'quote'}[0]}) {
                    $info{ $stocks, $prices } = $json_data->{'indicators'}{'quote'}[0]{$prices}[$tablerows];
                }

                # We always provide the adjclose as that is the real price for the security. 
                # The adjusted close metric returns the closing price of the stock for that day, adjusted for 
                # splits and dividends.
                if ($info{ $stocks, 'type' } =~ m/mutualfund/i) {
                    $info{ $stocks, 'nav' } = $info{ $stocks, 'adjclose' };
                }
                else {
                    $info{ $stocks, 'close' } = $info{ $stocks, 'adjclose' };
                }

                $info{ $stocks, 'last' } = $info{ $stocks, 'adjclose' };

                # The Yahoo JSON interface returns London prices in GBp (pence) instead of GBP (pounds)
                # and the Yahoo Base had a hack to convert them to GBP.  In theory all the callers
                # would correctly handle GBp as not the same as GBP, but they don't, and since
                # we had the hack before, let's add it back now.
                #
                # Convert GBp or GBX to GBP (divide price by 100).

                if ( ($info{$stocks,"currency"} eq "GBp") ||
                     ($info{$stocks,"currency"} eq "GBX")) {
                    for my $price (qw/open high low close last nav price adjclose regularMarketPrice chartPreviousClose/) {
                        if (defined ($info{$stocks, $price})) {
                            $info{$stocks,$price}=$info{$stocks,$price}/100;
                        }
                    }
                    $info{ $stocks, "currency"} = "GBP";
                }

                # Apply the same hack for Johannesburg Stock Exchange
                # (JSE) prices as they are returned in ZAc (cents)
                # instead of ZAR (rands). JSE symbols are suffixed
                # with ".JO" when querying Yahoo e.g. ANG.JO

                if ($info{$stocks,"currency"} eq "ZAc") {
                    for my $price (qw/open high low close last nav price adjclose regularMarketPrice chartPreviousClose/) {
                        if (defined ($info{$stocks, $price})) {
                            $info{$stocks,$price}=$info{$stocks,$price}/100;
                        }
                    }
                    $info{ $stocks, "currency"} = "ZAR";
                }

                # Apply the same hack for Tel Aviv Stock Exchange
                # (TASE) prices as they are returned in ILA (Agorot)
                # instead of ILS (Shekels). TASE symbols are suffixed
                # with ".TA" when querying Yahoo e.g. POLI.TA

                if ($info{$stocks,"currency"} eq "ILA") {
                    for my $price (qw/open high low close last nav price adjclose regularMarketPrice chartPreviousClose/) {
                        if (defined ($info{$stocks, $price})) {
                            $info{$stocks,$price}=$info{$stocks,$price}/100;
                        }
                    }
                    $info{ $stocks, "currency"} = "ILS";
                }

                # MS Windows strftime() does not support %T so use %H:%M:%S
                #  instead.
                $my_date =
                    localtime($json_timestamp)->strftime('%d.%m.%Y %H:%M:%S');

                $quoter->store_date( \%info, $stocks,
                                     { eurodate => $my_date } );

                $info{ $stocks, "success" } = 1;

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

# testing: perl "c:\Program Files (x86)\gnucash\bin\gnc-fq-dump" -v yahoo_chart BK FSPSX SBIN.NS

=head1 NAME

Finance::Quote::YahooChart - Obtain quotes from Yahoo Finance's Chart API call

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = $q->fetch('yahoo_chart','BK');

=head1 DESCRIPTION

This module fetches information from Yahoo using Chart sub-API. 

This module is loaded by default on a Finance::Quote object. It's
also possible to load it explicitly by placing "YahooChart" in the argument
list to Finance::Quote->new().

This module provides the "yahoo_chart" fetch method.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::YahooChart :
success date isodate volume currency method exchange type symbol
open high low close nav price adjclose 

=head1 SEE ALSO

=cut
