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

package Finance::Quote::IEXCloud;

require 5.005;

# VERSION

use strict;
use JSON qw( decode_json );
use HTTP::Request::Common;
use Text::Template;
use DateTime::Format::Strptime qw( strptime strftime );

my $IEX_URL     = Text::Template->new(TYPE => 'STRING', SOURCE => 'https://cloud.iexapis.com/v1/stock/{$symbol}/quote?token={$token}');
my $IEX_API_KEY = $ENV{"IEXCLOUD_API_KEY"};

sub methods { 
  return ( iexcloud => \&iexcloud,
           usa      => \&iexcloud,
           nasdaq   => \&iexcloud,
           nyse     => \&iexcloud );
}

{
    our @labels = qw/date isodate open high low close volume last/;
    sub labels {
        return ( iexcloud => \@labels, );
    }
}

sub iexcloud {
    my $quoter = shift;

    my @stocks = @_;
    my $quantity = @stocks;
    my ( %info, $reply, $url, $code, $desc, $body );
    my $ua = $quoter->user_agent();

    foreach my $symbol (@stocks) {
        $url = $IEX_URL->fill_in(HASH => { symbol => $symbol, token => $IEX_API_KEY});

        $reply = $ua->request( GET $url);
        $code  = $reply->code;
        $desc  = HTTP::Status::status_message($code);
        $body  = $reply->content;
  
        if ($code != 200) {
            $info{ $symbol, 'success' } = 0;
            $info{ $symbol, 'errormsg' } = $desc;
            next;
        }

        my $quote;
        eval {$quote = JSON::decode_json $body};
        if ($@) {
            $info{ $symbol, 'success' } = 0;
            $info{ $symbol, 'errormsg' } = $@;
            next;
        }

        if (not exists $quote->{'symbol'} or $quote->{'symbol'} ne $symbol) {
            $info{ $symbol, 'success' } = 0;
            $info{ $symbol, 'errormsg' } = "IEXCloud return and unexpected json result";
            next;
        }

        $info{ $symbol, 'success' } = 1;
        $info{ $symbol, 'symbol' }  = $symbol;
        $info{ $symbol, 'open' }    = $quote->{'open'} if $quote->{'open'}; 
        $info{ $symbol, 'close' }   = $quote->{'close'} if $quote->{'close'};
        $info{ $symbol, 'high' }    = $quote->{'high'} if $quote->{'high'};
        $info{ $symbol, 'low' }     = $quote->{'low'} if $quote->{'low'};
        $info{ $symbol, 'last' }    = $quote->{'latestPrice'} if $quote->{'latestPrice'};
        $info{ $symbol, 'volume' }  = $quote->{'latestVolume'};
        $info{ $symbol, 'method' }  = 'iexcloud';
       
        my $iex_date = $quote->{'latestTime'};  # eg. June 20, 2019
        my $time     = strptime('%b %d, %Y', $iex_date);
        
        my $isodate  = strftime('%F', $time);
        $quoter->store_date( \%info, $symbol, { isodate => $isodate } );
        
        $info{ $symbol, 'currency' }           = 'USD';
        $info{ $symbol, 'currency_set_by_fq' } = 1;
    }

    return wantarray() ? %info : \%info;
}

