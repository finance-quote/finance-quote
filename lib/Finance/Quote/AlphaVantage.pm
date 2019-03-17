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
use Time::HiRes qw(usleep clock_gettime);

# Alpha Vantage recommends that API call frequency does not extend far
# beyond ~1 call per second so that they can continue to deliver
# optimal server-side performance:
#   https://www.alphavantage.co/support/#api-key
our @alphaqueries=();
my $maxQueries = { quantity =>5 , seconds => 60}; # no more than x
                                                  # queries per y
                                                  # seconds, based on
                                                  # https://www.alphavantage.co/support/#support

my $ALPHAVANTAGE_URL =
    'https://www.alphavantage.co/query?function=TIME_SERIES_DAILY&outputsize=compact&datatype=json';
my $ALPHAVANTAGE_API_KEY = $ENV{'ALPHAVANTAGE_API_KEY'};

my %currencies_by_suffix = (

                        # Country		City/Exchange Name
    '.US'  => "USD",    # USA		AMEX, Nasdaq, NYSE
    '.A'   => "USD",    # USA		American Stock Exchange (ASE)
    '.B'   => "USD",    # USA		Boston Stock Exchange (BOS)
    '.N'   => "USD",    # USA		Nasdaq Stock Exchange (NAS)
    '.O'   => "USD",    # USA		NYSE Stock Exchange (NYS)
    '.OB'  => "USD",    # USA		OTC Bulletin Board
    '.PK'  => "USD",    # USA		Pink Sheets
    '.X'   => "USD",    # USA		US Options
    '.BA'  => "ARS",    # Argentina	Buenos Aires
    '.VI'  => "EUR",    # Austria		Vienna
    '.AX'  => "AUD",    # Australia
    '.SA'  => "BRL",    # Brazil		Sao Paolo
    '.BR'  => "EUR",    # Belgium		Brussels
    '.TO'  => "CAD",    # Canada		Toronto
    '.V'   => "CAD",    # 		Toronto Venture
    '.SN'  => "CLP",    # Chile		Santiago
    '.SS'  => "CNY",    # China		Shanghai
    '.SZ'  => "CNY",    # 		Shenzhen
    '.CO'  => "DKK",    # Denmark		Copenhagen
    '.PA'  => "EUR",    # France		Paris
    '.BE'  => "EUR",    # Germany		Berlin
    '.BM'  => "EUR",    # 		Bremen
    '.D'   => "EUR",    # 		Dusseldorf
    '.F'   => "EUR",    # 		Frankfurt
    '.H'   => "EUR",    # 		Hamburg
    '.HA'  => "EUR",    # 		Hanover
    '.MU'  => "EUR",    # 		Munich
    '.ME'  => "RUB",    # Russia	Moscow
    '.SG'  => "EUR",    # 		Stuttgart
    '.DE'  => "EUR",    # 		XETRA
    '.HK'  => "HKD",    # Hong Kong
    '.BO'  => "INR",    # India		Bombay
    '.CL'  => "INR",    # 		Calcutta
    '.NS'  => "INR",    # 		National Stock Exchange
    '.JK'  => "IDR",    # Indonesia	Jakarta
    '.I'   => "EUR",    # Ireland		Dublin
    '.TA'  => "ILS",    # Israel		Tel Aviv
    '.MI'  => "EUR",    # Italy		Milan
    '.KS'  => "KRW",    # Korea		Stock Exchange
    '.KQ'  => "KRW",    # 		KOSDAQ
    '.KL'  => "MYR",    # Malaysia	Kuala Lampur
    '.MX'  => "MXP",    # Mexico
    '.NZ'  => "NZD",    # New Zealand
    '.AS'  => "EUR",    # Netherlands	Amsterdam
    '.OL'  => "NOK",    # Norway		Oslo
    '.LM'  => "PEN",    # Peru		Lima
    '.IN'  => "EUR",    # Portugal	Lisbon
    '.SI'  => "SGD",    # Singapore
    '.BC'  => "EUR",    # Spain		Barcelona
    '.BI'  => "EUR",    # 		Bilbao
    '.MF'  => "EUR",    # 		Madrid Fixed Income
    '.MC'  => "EUR",    # 		Madrid SE CATS
    '.MA'  => "EUR",    # 		Madrid
    '.VA'  => "EUR",    # 		Valence
    '.ST'  => "SEK",    # Sweden		Stockholm
    '.HE'  => "EUR",    # Finland		Helsinki
    '.S'   => "CHF",    # Switzerland	Zurich
    '.TW'  => "TWD",    # Taiwan		Taiwan Stock Exchange
    '.TWO' => "TWD",    # 		OTC
    '.BK'  => "THB",    # Thialand	Thailand Stock Exchange
    '.TH'  => "THB",    # 		??? From Asia.pm, (in Thai Baht)
    '.L'   => "GBP",    # United Kingdom	London
    '.IL'  => "USD",    # United Kingdom	London USD*100
    '.VX'  => "CHF",    # Switzerland
    '.SW'  => "CHF",    # Switzerland
);


sub methods {
    return ( alphavantage => \&alphavantage,
             canada       => \&alphavantage,
             usa          => \&alphavantage,
             nyse         => \&alphavantage,
             nasdaq       => \&alphavantage,
             vanguard     => \&alphavantage,
    );
}

{
    my @labels = qw/date isodate open high low close volume last/;

    sub labels {
        return ( alphavantage => \@labels, );
    }
}

sub sleep_before_query {
    # wait till we can query again
    my $q = $maxQueries->{quantity}-1;
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

sub alphavantage {
    my $quoter = shift;

    my @stocks = @_;
    my $quantity = @stocks;
    my ( %info, $reply, $url, $code, $desc, $body );
    my $ua = $quoter->user_agent();
    my $launch_time = clock_gettime();

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

        my $get_content = sub {
            sleep_before_query();
            my $time=int(clock_gettime()-$launch_time);
            # print STDERR "Query at:".$time."\n";
            $reply = $ua->request( GET $url);

            $code = $reply->code;
            $desc = HTTP::Status::status_message($code);
            $body = $reply->content;
        };

        &$get_content();

        if ($code != 200) {
            $info{ $stock, 'success' } = 0;
            $info{ $stock, 'errormsg' } = $desc;
            next;
        }

        my $json_data;
        eval {$json_data = JSON::decode_json $body};
        if ($@) {
            $info{ $stock, 'success' } = 0;
            $info{ $stock, 'errormsg' } = $@;
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
            $info{ $stock, 'success' } = 0;
            $info{ $stock, 'errormsg' } =
                $json_data->{'Error Message'} || $json_data->{'Information'};
            next;
        }

        if (!$json_data->{'Meta Data'}) {
            $info{ $stock, 'success' } = 0;
            $info{ $stock, 'errormsg' } = ( $json_data->{'Information'} || "No useable data returned" ) ;
            next;
        }

        my $last_refresh = $json_data->{'Meta Data'}->{'3. Last Refreshed'}; # when market is open this returns an isodate + time, otherwise only the isodate
        $last_refresh = substr($last_refresh,0,10);  # remove time if returned
        if ( !$last_refresh ) {
            $info{ $stock, 'success' } = 0;
            $info{ $stock, 'errormsg' } = "json_data doesn't contain Last Refreshed";
            next;
        }
        my $isodate = substr( $last_refresh, 0, 10 );
        if ( !$json_data->{'Time Series (Daily)'} ) {
            $info{ $stock, 'success' } = 0;
            $info{ $stock, 'errormsg' } = "json_data doesn't contain Time Series hash";
            next;
        }
        if ( !$json_data->{'Time Series (Daily)'}->{$last_refresh} ) {
            $info{ $stock, 'success' } = 0;
            $info{ $stock, 'errormsg' } = "json_data doesn't contain latest refresh data in Time Series hash";
            next;
        }

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
        if ( $stock =~ /(\..*)/ ) {
            my $suffix = uc $1;
            if ( $currencies_by_suffix{$suffix} ) {
                $info{ $stock, 'currency' } = $currencies_by_suffix{$suffix};

                # divide GBP quotes by 100
                if ( ($info{ $stock, 'currency' } eq 'GBP') || ($info{$stock,'currency'} eq 'GBX') ) {
                    foreach my $field ( $quoter->default_currency_fields ) {
                        next unless ( $info{ $stock, $field } );
                        $info{ $stock, $field } =
                            $quoter->scale_field( $info{ $stock, $field },
                                                  0.01 );
                    }
                }
                # divide USD quotes by 100 if suffix is '.IL'
                if ( ($suffix eq '.IL') && ($info{$stock,'currency'} eq 'USD') ) {
                    foreach my $field ( $quoter->default_currency_fields ) {
                        next unless ( $info{ $stock, $field } );
                        $info{ $stock, $field } =
                            $quoter->scale_field( $info{ $stock, $field },
                                                  0.01 );
                    }
                }
            }
        }
        else {
            $info{ $stock, 'currency' } = 'USD';
        }

        $info{ $stock, "currency_set_by_fq" } = 1;

    }

    return wantarray() ? %info : \%info;
}
