#!/usr/bin/perl -w
#    This module is based on the Finance::Quote::YahooJSON module
#
#    The code has been modified by Jefferson Fermo to
#    retrieve stock information from Philippine Stock Exchange through json calls
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

package Finance::Quote::PseJSON;

require 5.005;

use strict;
use JSON qw( decode_json );
use vars qw($VERSION $PSE_URL);
use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;
use Time::Piece;
use Data::Dumper;
use DateTime::Format::Strptime;

our $VERSION = '1.35'; # VERSION

my $PSE_URL= 'http://pse.com.ph/stockMarket/home.html?method=getSecuritiesAndIndicesForPublic';

sub methods {
    return ( pse_json => \&pse_json,
    );
}
{
    my @labels = qw/name last date isodate price timezone
        volume currency method exchange/;

    sub labels {
        return ( pse_json => \@labels,
        );
    }
}

sub pse_json {

    my $quoter = shift;
    my @stocks = @_;
    my ( %info, $reply, $url, $te, $ts, $row, @cells, $ce );
    my ( $my_date, $my_last, $my_p_change, $my_volume, $my_high, $my_low,
         $my_open );
    my $ua = $quoter->user_agent();
    
    $ua->timeout(10);
    $ua->agent("Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.9.0.1) Gecko/2008072820 Firefox/3.0.1");

    # PSE infra doenst like TE header in http get, turn it off
    push(@LWP::Protocol::http::EXTRA_SOCK_OPTS, SendTE => 0);

    $reply = $ua->request( GET $PSE_URL );
 
#Response variables available:
#Response code: 			$code
#Response description: 	$desc
#HTTP Headers:				$headers
#Response body				$body

    my $code    = $reply->code;
    my $desc    = HTTP::Status::status_message($code);
    my $headers = $reply->headers_as_string;
    my $body    = $reply->content;

    if ( $code == 200 ) {

        my $json_data = JSON::decode_json $body;
    
#HTTP_Response succeeded - parse the data

	if ( keys( $json_data ) <= 1 ) {
		
	    foreach my $stocks (@stocks) {
	        $info{ $stocks, "success" } = 0;
		$info{ $stocks, "errormsg" } =
			"Error retrieving quote for $stocks. Attempt to fetch the URL $PSE_URL resulted in zero data: $json_data";
	    }
	}
	else {
	    foreach my $stocks (@stocks) {

		my $stocks_date = $json_data->[0]->{securityAlias};
		
		my $parser = DateTime::Format::Strptime->new(
				pattern => '%m/%d/%Y %I:%M %p %Z',
				on_error => 'croak',
				);

		my $dt = $parser->parse_datetime( $stocks_date . ' PHT' );

	        $info{ $stocks, "symbol" } = $stocks;
		my $stock_found = 0;
		for my $item( @{$json_data} ){

		     if ( $item->{'securitySymbol'} =~ m/^$stocks$/ ) {
			$stock_found = 1;
			my $json_price = $item->{'lastTradedPrice'};
			my $json_name = $item->{'securityAlias'};
			my $json_volume = $item->{'totalVolume'};

			$info{ $stocks, "last" }   = $json_price;
			$info{ $stocks, "price" }   = $json_price;
			$info{ $stocks, "success" } = 1;
			$info{ $stocks, "method" } = "pse_json";
			$info{ $stocks, "name" }   = $stocks . ' (' . $json_name . ')';			
			$info{ $stocks, "volume" }   = $json_volume;
			$info{ $stocks, "exchange" } =
                    "Sourced from PSE (as JSON)";
			$info{ $stocks, "currency" } = "PHP";
			$info{ $stocks, "timezone" } = "PHT";
			$info{ $stocks, "date" } = $dt->strftime('%m/%d/%y');
		        $info{ $stocks, "time" } = $dt->strftime('%H:%M:%S');

		     } 
		}
		if ( $stock_found == 0) {
		         $info{ $stocks, "success" } = 0;
		         $info{ $stocks, "errormsg" } =
				 "Error finding stocks " . $stocks . "from pse data";
		}
		
	    }
	}

    }
#HTTP request fail
    else {
        foreach my $stocks (@stocks) {
            $info{ $stocks, "success" } = 0;
	    $info{ $stocks, "errormsg" } =
		    "Error retrieving quote for $stocks. Attempt to fetch the URL $PSE_URL resulted in HTTP response $code ($desc)";
	}
    }

    return wantarray() ? %info : \%info;
    return \%info;
}

1;

=head1 NAME

Finance::Quote::PseJSON - Obtain quotes from http://pse.com.ph/ through JSON call

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("pse_json","AP");

=head1 DESCRIPTION

This module fetches information from PSE as JSON

This module is loaded by default on a Finance::Quote object. It's
also possible to load it explicity by placing "PseJSON" in the argument
list to Finance::Quote->new().

This module provides the "pse_json" fetch method.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::PseJSON :
name, last, date, time volume, method, exchange.

=head1 SEE ALSO

=cut
