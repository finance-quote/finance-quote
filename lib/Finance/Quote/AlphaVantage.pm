#!/usr/bin/perl -w

package Finance::Quote::AlphaVantage;

require 5.005;

use strict;
use JSON qw( decode_json );
use HTTP::Request::Common;

my $ALPHAVANTAGE_URL =
    'https://www.alphavantage.co/query?function=TIME_SERIES_INTRADAY&interval=1min';
my $ALPHAVANTAGE_API_KEY = $ENV{"ALPHAVANTAGE_API_KEY"};

die
    "Expected ALPHAVANTAGE_API_KEY to be set; get an API key at https://www.alphavantage.co"
    unless ( defined $ALPHAVANTAGE_API_KEY );

sub methods {
    return ( alphavantage => \&alphavantage, );

    my @labels = qw/date isodate open high low close volume/;

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
        my ($latest);

        if ( $json_data->{"Time Series (1min)"} ) {
            $info{ $stock, "success" } = 1;

            $latest = ( keys( $json_data->{"Time Series (1min)"} ) )[0];

            $info{ $stock, "open" } =
                $json_data->{"Time Series (1min)"}->{$latest}->{"1. open"};
            $info{ $stock, "close" } =
                $json_data->{"Time Series (1min)"}->{$latest}->{"4. close"};
            $info{ $stock, "high" } =
                $json_data->{"Time Series (1min)"}->{$latest}->{"2. high"};
            $info{ $stock, "low" } =
                $json_data->{"Time Series (1min)"}->{$latest}->{"3. low"};
            $info{ $stock, "volume" } =
                $json_data->{"Time Series (1min)"}->{$latest}->{"5. volume"};
            $info{ $stock, "isodate" } = substr( $latest, 0, 10 );

            $quoter->store_date( \%info, $stock, { isodate => $latest } );
        }
        else {
            $info{ $stock, "success" } = 0;
            $info{ $stock, "errormsg" } =
                $json_data->{"Error Message"} || $json_data->{"Information"};
        }
    }

    return wantarray() ? %info : \%info;
}
