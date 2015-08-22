#!/usr/bin/perl -w
#    This module is based on the Finance::Quote::BSERO module
#    It was first called BOMSE but has been renamed to yahooJSON
#    since it gets a lot of quotes besides Indian
#
#    The code has been modified by Abhijit K to
#    retrieve stock information from Yahoo Finance through json calls
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

package Finance::Quote::YahooJSON;

require 5.005;

use strict;
use JSON qw( decode_json );
use vars qw($VERSION $YIND_URL_HEAD $YIND_URL_TAIL);
use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;
use Time::Piece;

# VERSION

my $YIND_URL_HEAD = 'http://finance.yahoo.com/webservice/v1/symbols/';
my $YIND_URL_TAIL = '/quote?format=json';
my %suffix_to_currency = (
    NS => 'INR',
    CL => 'INR',
    BO => 'INR',
);

sub methods {
    return ( yahoo_json => \&yahoo_json,
    );
}
{
    my @labels = qw/name last date isodate p_change open high low close
        volume currency method exchange type/;

    sub labels {
        return ( yahoo_json => \@labels,
        );
    }
}

sub yahoo_json {

    my $quoter = shift;
    my @stocks = @_;
    my ( %info, $reply, $url, $te, $ts, $row, @cells, $ce );
    my ( $my_date, $my_last, $my_p_change, $my_volume, $my_high, $my_low,
         $my_open );
    my $ua = $quoter->user_agent();

    foreach my $stocks (@stocks) {

        $url   = $YIND_URL_HEAD . $stocks . $YIND_URL_TAIL;
        $reply = $ua->request( GET $url);

        my $code    = $reply->code;
        my $desc    = HTTP::Status::status_message($code);
        my $headers = $reply->headers_as_string;
        my $body    = $reply->content;

        #Response variables available:
        #Response code: 			$code
        #Response description: 	$desc
        #HTTP Headers:				$headers
        #Response body				$body

        $info{ $stocks, "symbol" } = $stocks;

        if ( $code == 200 ) {

            #HTTP_Response succeeded - parse the data
            my $json_data = JSON::decode_json $body;

            #print ref($json_data);
            #print "size of hash:  " . keys( $json_data ) . ".\n";

            my $json_data_count = $json_data->{'list'}{'meta'}{'count'};

            if ( $json_data_count != 1 ) {
                $info{ $stocks, "success" } = 0;
                $info{ $stocks, "errormsg" } =
                    "Error retrieving quote for $stocks - no listing for this name found. Please check scrip name and the two letter extension (if any)";

            }
            else {
                my $json_resources = $json_data->{'list'}{'resources'}[0];
                my $json_response_type =
                    $json_resources->{'resource'}{classname};

                # TODO: Check if $json_response_type is "Quote"
                # before attempting anything else
                my $json_symbol =
                    $json_resources->{'resource'}{'fields'}{'symbol_requested'}
                    || $json_resources->{'resource'}{'fields'}{'symbol'};
                my $json_volume =
                    $json_resources->{'resource'}{'fields'}{'volume'};
                my $json_timestamp =
                    $json_resources->{'resource'}{'fields'}{'ts'};
                my $json_name = $json_resources->{'resource'}{'fields'}{'name'};
                my $json_type = $json_resources->{'resource'}{'fields'}{'type'};
                my $json_price =
                    $json_resources->{'resource'}{'fields'}{'price'};
                my $json_utctime =
                    $json_resources->{'resource'}{'fields'}{'utctime'};
                my $json_currency =
                    $json_resources->{'resource'}{'fields'}{'currency'};

                $info{ $stocks, "success" } = 1;
                $info{ $stocks, "exchange" } =
                    "Sourced from Yahoo Finance (as JSON)";
                $info{ $stocks, "method" } = "yahoo_json";
                $info{ $stocks, "name" }   = $stocks . ' (' . $json_name . ')';
                $info{ $stocks, "type" }   = $json_type;
                $info{ $stocks, "last" }   = $json_price;
                $info{ $stocks, "volume" }   = $json_volume;
                $info{ $stocks, "isodate" } = ( $json_utctime =~ /dddd-dd-dd/ );
                if (defined $json_currency and length $json_currency) {
                    $info{ $stocks, "currency" } = $json_currency;
                } else {
                    if ($stocks =~ /\.([^.]+)$/ ) { # find suffix
                        if (exists $suffix_to_currency{$1}) {
                            $info{ $stocks, "currency" } = $suffix_to_currency{$1};
                        }
                    }
                }

                $my_date = localtime($json_timestamp)->strftime('%d.%m.%Y %T');
                if ( $json_utctime =~ /(\d\d\d\d)-(\d\d)-(\d\d)/ ) {
                    $my_date = $3.".".$2.".".$1.".";
                }

                $quoter->store_date( \%info, $stocks,
                                     { eurodate => $my_date } );

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

Finance::Quote::YahooJSON - Obtain quotes from Yahoo Finance through JSON call

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("yahoo_json","SBIIN.NS");

=head1 DESCRIPTION

This module fetches information from Yahoo as JSON

This module is loaded by default on a Finance::Quote object. It's
also possible to load it explicity by placing "YahooJSON" in the argument
list to Finance::Quote->new().

This module provides the "yahoo_json" fetch method.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::YahooJSON :
name, last, isodate, volume, method, exchange.

=head1 SEE ALSO

=cut
