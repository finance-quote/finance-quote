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

package Finance::Quote::IEXTrading;

require 5.005;

# VERSION

use strict;
use JSON qw( decode_json );
use HTTP::Request::Common;
use Text::Template;
use DateTime::Format::Strptime qw( strptime strftime );

my $IEX_URL = Text::Template->new(TYPE => 'STRING', SOURCE => 'https://api.iextrading.com/1.0/stock/{$symbol}/chart/1m');

sub methods {
    return ( iextrading => \&iextrading );

    our @labels = qw/date isodate open high low close volume last/;

    sub labels {
        return ( alphavantage => \@labels, );
    }
}

sub iextrading {
    my $quoter = shift;

    my @stocks = @_;
    my $quantity = @stocks;
    my ( %info, $reply, $url, $code, $desc, $body );
    my $ua = $quoter->user_agent();

    foreach my $symbol (@stocks) {
        $url = $IEX_URL->fill_in(HASH => { symbol => $symbol});

        $reply = $ua->request( GET $url);
        $code  = $reply->code;
        $desc  = HTTP::Status::status_message($code);
        $body  = $reply->content;
  
        if ($code != 200) {
            $info{ $symbol, 'success' } = 0;
            $info{ $symbol, 'errormsg' } = $desc;
            next;
        }

        my $json_data;
        eval {$json_data = JSON::decode_json $body};
        if ($@) {
            $info{ $symbol, 'success' } = 0;
            $info{ $symbol, 'errormsg' } = $@;
            next;
        }

        if (@$json_data == 0) {
            $info{ $symbol, 'success' } = 0;
            $info{ $symbol, 'errormsg' } = "No useable data returned";
            next;
        }

        my $quote = $json_data->[-1];

        $info{ $symbol, 'success' } = 1;
        $info{ $symbol, 'symbol' }  = $symbol;
        $info{ $symbol, 'open' }    = $quote->{'open'}; 
        $info{ $symbol, 'close' }   = $quote->{'close'};
        $info{ $symbol, 'high' }    = $quote->{'high'};
        $info{ $symbol, 'low' }     = $quote->{'low'};
        $info{ $symbol, 'last' }    = $quote->{'close'};
        $info{ $symbol, 'volume' }  = $quote->{'volume'};
        $info{ $symbol, 'method' }  = 'alphavantage';
        
        my $isodate = $quote->{'date'};
        $quoter->store_date( \%info, $symbol, { isodate => $isodate } );
        
        $info{ $symbol, 'currency' }           = 'USD';
        $info{ $symbol, 'currency_set_by_fq' } = 1;
    }

    return wantarray() ? %info : \%info;
}

