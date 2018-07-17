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

package Finance::Quote::AlphaVantage_Batch;

require 5.005;

# VERSION

use strict;
use JSON qw( decode_json );
use HTTP::Request::Common;
use Time::HiRes qw(usleep clock_gettime);
use List::MoreUtils qw(natatime);

# Alpha Vantage recommends that API call frequency does not extend far
# beyond ~1 call per second so that they can continue to deliver
# optimal server-side performance:
#   https://www.alphavantage.co/support/#api-key
our @alphaqueries=();
my $maxQueries = { quantity =>20 , seconds => 65}; # no more than x queries per y seconds

my $ALPHAVANTAGE_URL =
    'https://www.alphavantage.co/query?function=BATCH_STOCK_QUOTES&datatype=json';
my $ALPHAVANTAGE_API_KEY = $ENV{'ALPHAVANTAGE_API_KEY'};

sub methods {
    return ( alphavantage_batch => \&alphavantage_batch,
             canada       => \&alphavantage_batch,
             usa          => \&alphavantage_batch,
             nyse         => \&alphavantage_batch,
             nasdaq       => \&alphavantage_batch,
             vanguard     => \&alphavantage_batch,
    );

    our @labels = qw/date isodate volume last/;

    sub labels {
        return ( alphavantage_batch => \@labels, );
    }
}

sub sleep_before_query {
    # wait till we can query again
    my $q = $maxQueries->{quantity};
    if ( $#alphaqueries >= $q ) {
        my $time_since_x_queries = clock_gettime()-$alphaqueries[$q];
        # print STDERR "LAST QUERY $time_since_x_queries\n";
        if ($time_since_x_queries < $maxQueries->{seconds}) {
            my $sleeptime = ($maxQueries->{seconds} - $time_since_x_queries) * 1000000;
            # print STDERR "SLEEP $sleeptime\n";
            usleep( $sleeptime );
            # print STDERR "CONTINUE\n";
        }
    }
    unshift @alphaqueries, clock_gettime();
    pop @alphaqueries while $#alphaqueries>$q; # remove unnecessary data
    # print STDERR join(",",@alphaqueries)."\n";
}

sub alphavantage_batch {
    my $quoter = shift;

    my @stocks = @_;
    my $quantity = @stocks;
    my ( %info, $reply, $url, $code, $desc, $body );
    my $ua = $quoter->user_agent();

    my $stock_iter = natatime 100, @stocks;
    while ( my @stocks_chunk = $stock_iter->() ) {

        if ( !defined $ALPHAVANTAGE_API_KEY ) {
            foreach my $stock (@stocks_chunk) {
                $info{ $stock, 'success' } = 0;
                $info{ $stock, 'errormsg' } =
                    'Expected ALPHAVANTAGE_API_KEY to be set; get an API key at https://www.alphavantage.co';
            }
            next;
        }

        $url =
              $ALPHAVANTAGE_URL
            . '&apikey='
            . $ALPHAVANTAGE_API_KEY
            . '&symbols='
            . join(',', @stocks_chunk);

        my $get_content = sub {
            sleep_before_query();
            $reply = $ua->request( GET $url);

            $code = $reply->code;
            $desc = HTTP::Status::status_message($code);
            $body = $reply->content;
        };

        &$get_content();

        if ($code != 200) {
            foreach my $stock (@stocks_chunk) {
                $info{ $stock, 'success' } = 0;
                $info{ $stock, 'errormsg' } = $desc;
            }
            next;
        }

        my $json_data;
        eval {$json_data = JSON::decode_json $body};
        if ($@) {
            foreach my $stock (@stocks_chunk) {
                $info{ $stock, 'success' } = 0;
                $info{ $stock, 'errormsg' } = $@;
            }
            next;
        }

        my $try_cnt = 0;
        while (($try_cnt < 5) && ($json_data->{'Information'})) {
            # print STDERR "INFORMATION:".$json_data->{'Information'}."\n";
            # print STDERR "ADDITIONAL SLEEPING HERE !";
            sleep (20);
            &$get_content();
            eval {$json_data = JSON::decode_json $body};
            $try_cnt += 1;
        }

        if ( !$json_data || $json_data->{'Error Message'} ) {
            foreach my $stock (@stocks_chunk) {
                $info{ $stock, 'success' } = 0;
                $info{ $stock, 'errormsg' } =
                    $json_data->{'Error Message'} || $json_data->{'Information'};
            }
            next;
        }

        if (!$json_data->{'Meta Data'}) {
            foreach my $stock (@stocks_chunk) {
                $info{ $stock, 'success' } = 0;
                $info{ $stock, 'errormsg' } = ( $json_data->{'Information'} || "No useable data returned" ) ;
            }
            next;
        }

        if ( !$json_data->{'Stock Quotes'} ) {
            foreach my $stock (@stocks_chunk) {
                $info{ $stock, 'success' } = 0;
                $info{ $stock, 'errormsg' } = "json_data doesn't contain Stock Quotes hash";
            }
            next;
        }

        foreach my $bq (@{$json_data->{'Stock Quotes'}}) {
            foreach my $stock (@stocks_chunk) {
                if ( $bq->{'1. symbol'} ne $stock ) {
                    next;
                }

                # $bq holds data as
                # {
                #     '1. symbol'     DIS,
                #     '2. price'      110.2000,
                #     '3. volume'     8194127
                #     '4. timestamp'  2018-07-16 16:02:52,
                # }

                $info{ $stock, 'success' } = 1;
                $info{ $stock, 'symbol' }  = $bq->{'1. symbol'};
                $info{ $stock, 'last' }    = $bq->{'2. price'};
                $info{ $stock, 'volume' }  = $bq->{'3. volume'};
                $info{ $stock, 'method' }  = 'alphavantage_batch';
                $info{ $stock, 'currency' } = 'USD';
                $quoter->store_date( \%info, $stock, { isodate => $bq->{'4. timestamp'} } );

                $info{ $stock, "currency_set_by_fq" } = 1;
            }
        }
    }

    return wantarray() ? %info : \%info;
}
