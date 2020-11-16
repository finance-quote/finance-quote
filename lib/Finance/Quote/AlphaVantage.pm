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
#    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
#    02110-1301, USA

# 2019-12-01: Added additional labels for net and p_change. Set
#             close to previous close as returned in the JSON.
#             Bruce Schuck (bschuck at asgard hyphen systems dot com)

package Finance::Quote::AlphaVantage;

use strict;
use JSON qw( decode_json );
use HTTP::Request::Common;

# VERSION

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
    'https://www.alphavantage.co/query?function=GLOBAL_QUOTE&datatype=json';

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
    '.FRK' => "EUR",    # 		Frankfurt
    '.H'   => "EUR",    # 		Hamburg
    '.HA'  => "EUR",    # 		Hanover
    '.MU'  => "EUR",    # 		Munich
    '.DEX' => "EUR",    # 		Xetra
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
    '.AMS' => "EUR",    # Netherlands	Amsterdam
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
    '.STO' => "SEK",    # Sweden		Stockholm
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
    );
}

{
    my @labels = qw/date isodate open high low close volume last net p_change/;

    sub labels {
        return ( alphavantage => \@labels, );
    }
}

sub sleep_before_query {
    # wait till we can query again
    my $q = $maxQueries->{quantity}-1;
    if ( $#alphaqueries >= $q ) {
        my $time_since_x_queries = time()-$alphaqueries[$q];
        # print STDERR "LAST QUERY $time_since_x_queries\n";
        if ($time_since_x_queries < $maxQueries->{seconds}) {
            my $sleeptime = ($maxQueries->{seconds} - $time_since_x_queries) ;
            # print STDERR "SLEEP $sleeptime\n";
            sleep( $sleeptime );
            # print STDERR "CONTINUE\n";
        }
    }
    unshift @alphaqueries, time();
    pop @alphaqueries while $#alphaqueries>$q; # remove unnecessary data
    # print STDERR join(",",@alphaqueries)."\n";
}

sub alphavantage {
    my $quoter = shift;

    my @stocks = @_;
    my $quantity = @stocks;
    my ( %info, $reply, $url, $code, $desc, $body );
    my $ua = $quoter->user_agent();
    my $launch_time = time();

    my $token = exists $quoter->{module_specific_data}->{alphavantage}->{API_KEY} ? 
                $quoter->{module_specific_data}->{alphavantage}->{API_KEY}        :
                $ENV{"ALPHAVANTAGE_API_KEY"};

    foreach my $stock (@stocks) {

        if ( !defined $token ) {
            $info{ $stock, 'success' } = 0;
            $info{ $stock, 'errormsg' } =
                'An AlphaVantage API is required. Get an API key at https://www.alphavantage.co';
            next;
        }

        $url =
              $ALPHAVANTAGE_URL
            . '&apikey='
            . $token
            . '&symbol='
            . $stock;

        my $get_content = sub {
            sleep_before_query();
            my $time=int(time()-$launch_time);
            # print STDERR "Query at:".$time."\n";
            $reply = $ua->request( GET $url);

            $code = $reply->code;
            $desc = HTTP::Status::status_message($code);
            $body = $reply->content;
            # print STDERR "AlphaVantage returned: $body\n";
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
        while (($try_cnt < 5) && ($json_data->{'Note'})) {
            # print STDERR "NOTE:".$json_data->{'Note'}."\n";
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

        my $quote = $json_data->{'Global Quote'};
        if ( ! %{$quote} ) {
            $info{ $stock, 'success' } = 0;
            $info{ $stock, 'errormsg' } = "json_data doesn't contain Global Quote";
            next;
        }

        # %ts holds data as
        #  {
        #     "Global Quote": {
        #         "01. symbol": "SOLB.BR",
        #         "02. open": "104.2000",
        #         "03. high": "104.9500",
        #         "04. low": "103.4000",
        #         "05. price": "104.0000",
        #         "06. volume": "203059",
        #         "07. latest trading day": "2019-11-29",
        #         "08. previous close": "105.1500",
        #         "09. change": "-1.1500",
        #         "10. change percent": "-1.0937%"
        #     }
        # }

        # remove trailing percent sign, if present
        $quote->{'10. change percent'} =~ s/\%$//;

        $info{ $stock, 'success' } = 1;
        $info{ $stock, 'success' }  = 1;
        $info{ $stock, 'symbol' }   = $quote->{'01. symbol'};
        $info{ $stock, 'open' }     = $quote->{'02. open'};
        $info{ $stock, 'high' }     = $quote->{'03. high'};
        $info{ $stock, 'low' }      = $quote->{'04. low'};
        $info{ $stock, 'last' }     = $quote->{'05. price'};
        $info{ $stock, 'volume' }   = $quote->{'06. volume'};
        $info{ $stock, 'close' }    = $quote->{'08. previous close'};
        $info{ $stock, 'net' }      = $quote->{'09. change'};
        $info{ $stock, 'p_change' } = $quote->{'10. change percent'};
        $info{ $stock, 'method' }  = 'alphavantage';
        $quoter->store_date( \%info, $stock, { isodate => $quote->{'07. latest trading day'} } );

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
1;

=head1 NAME

Finance::Quote::AlphaVantage - Obtain quotes from https://iexcloud.io

=head1 SYNOPSIS

    use Finance::Quote;
    
    $q = Finance::Quote->new('AlphaVantage', alphavantage => {API_KEY => 'your-alphavantage-api-key'});

    %info = Finance::Quote->fetch("IBM", "AAPL");

=head1 DESCRIPTION

This module fetches information from https://www.alphavantage.co.

This module is loaded by default on a Finance::Quote object. It's also possible
to load it explicity by placing "AlphaVantage" in the argument list to
Finance::Quote->new().

This module provides the "alphavantage" fetch method.

=head1 API_KEY

https://www.alphavantage.co requires users to register and obtain an API key, which
is also called a token.  The token is a sequence of random characters.

The API key may be set by either providing a module specific hash to
Finance::Quote->new as in the above example, or by setting the environment
variable ALPHAVANTAGE_API_KEY.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::AlphaVantage :
symbol, open, close, high, low, last, volume, method, isodate, currency.

=cut
