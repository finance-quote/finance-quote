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

use strict;
use JSON qw( decode_json );
use HTTP::Request::Common;
use Text::Template;
use DateTime::Format::Strptime qw( strptime strftime );

# VERSION

my $IEX_URL = Text::Template->new(TYPE => 'STRING', SOURCE => 'https://cloud.iexapis.com/v1/stock/{$symbol}/quote?token={$token}');

sub methods { 
  return ( iexcloud => \&iexcloud,
           usa      => \&iexcloud,
           nasdaq   => \&iexcloud,
           nyse     => \&iexcloud );
}

{
    our @labels = qw/symbol open close high low last volume method isodate currency/;

    sub labels {
        return ( iexcloud => \@labels, );
    }
}

sub iexcloud {
    my $quoter = shift;

    my $token = exists $quoter->{module_specific_data}->{iexcloud}->{API_KEY} ? 
                $quoter->{module_specific_data}->{iexcloud}->{API_KEY}        :
                $ENV{"IEXCLOUD_API_KEY"};

    my @stocks = @_;
    my $quantity = @stocks;
    my ( %info, $reply, $url, $code, $desc, $body );
    my $ua = $quoter->user_agent();

    die "IEXCloud API_KEY not defined.  See documentation." unless defined $token;

    foreach my $symbol (@stocks) {
        $url = $IEX_URL->fill_in(HASH => { symbol => $symbol, token => $token});

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
        $info{ $symbol, 'volume' }  = $quote->{'latestVolume'} if $quote->{'latestVolume'};
        $info{ $symbol, 'method' }  = 'iexcloud';
       
        my $iex_date = $quote->{'latestUpdate'};  # milliseconds since midnight Jan 1, 1970
        my $time     = strptime('%s', int($iex_date/1000.0));
        my $isodate  = strftime('%F', $time);
        $quoter->store_date( \%info, $symbol, { isodate => $isodate } );
        
        $info{ $symbol, 'currency' }           = 'USD';
        $info{ $symbol, 'currency_set_by_fq' } = 1;
    }

    return wantarray() ? %info : \%info;
}
1;

=head1 NAME

Finance::Quote::IEXClound - Obtain quotes from https://iexcloud.io

=head1 SYNOPSIS

    use Finance::Quote;
    
    $q = Finance::Quote->new('IEXCloud', iexcloud => {API_KEY => 'your-iexcloud-api-key'});

    %info = Finance::Quote->fetch("IBM", "AAPL");

=head1 DESCRIPTION

This module fetches information from https://iexcloud.io.

This module is loaded by default on a Finance::Quote object. It's
also possible to load it explicity by placing "IEXCloud" in the argument
list to Finance::Quote->new().

This module provides the "iexcloud" fetch method.

=head1 API_KEY

https://iexcloud.io requires users to register and obtain an API key, which
is also called a token.  The token may contain a prefix string, such as 'pk_'
and then a sequence of random digits.

The API key may be set by either providing a module specific hash to
Finance::Quote->new as in the above example, or by setting the environment
variable IEXCLOUD_API_KEY.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::IEXClound :
symbol, open, close, high, low, last, volume, method, isodate, currency.

=cut
