#!/usr/bin/perl -w
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

package Finance::Quote::TwelveData;

require 5.005;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use strict;
use JSON qw( decode_json );
use HTTP::Request::Common;
use Text::Template;
use DateTime::Format::Strptime qw( strptime strftime );

# VERSION

my $URL      = Text::Template->new(TYPE => 'STRING', SOURCE => 'https://api.twelvedata.com/quote?symbol={$symbol}&apikey={$token}');
my $THROTTLE = 1.05 * 60.0/8.0;  # 5% more than maximum seconds / request for free tier
my $AGENT    = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/113.0.0.0 Safari/537.36';

sub methods { 
  return ( twelvedata => \&twelvedata );
}

sub parameters {
  return ('API_KEY');
}

{
    our @labels = qw/symbol name exchange currency isodate currency open high low close/;

    sub labels {
        return ( iexcloud => \@labels );
    }
}


sub twelvedata {
    my $quoter = shift;

    my @stocks = @_;
    my $quantity = @stocks;
    my ( %info, $reply, $url, $code, $desc, $body, $mark );
    my $ua = $quoter->user_agent();
    my $agent = $ua->agent();
    $ua->agent($AGENT);

    my $token = exists $quoter->{module_specific_data}->{twelvedata}->{API_KEY} ? 
                $quoter->{module_specific_data}->{twelvedata}->{API_KEY}        :
                $ENV{"TWELVEDATA_API_KEY"};

    foreach my $symbol (@stocks) {

        if ( !defined $token ) {
            $info{ $symbol, 'success' } = 0;
            $info{ $symbol, 'errormsg' } =
                'TwelveData API_KEY not defined. Get an API key at https://twelvedata.com';
            next;
        }

        # Rate limit - first time through loop, mark is negative
        $mark -= time();
        ### TwelveData Mark: $mark
        sleep($mark) if $mark > 0;
        $mark  = time() + $THROTTLE;

        $url   = $URL->fill_in(HASH => {symbol => $symbol, token => $token});
        $reply = $ua->request(GET $url);
        
        ### url: $url
        ### reply: $reply
        
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

        if (exists $quote->{'status'} and $quote->{'status'} eq 'error') {
            $info{ $symbol, 'success' } = 0;
            $info{ $symbol, 'errormsg' } = $quote->{'message'};
            next;
        }

        if (not exists $quote->{'symbol'} or $quote->{'symbol'} ne $symbol) {
            $info{ $symbol, 'success' } = 0;
            $info{ $symbol, 'errormsg' } = "TwevleData return and unexpected json result";
            next;
        }

        $info{ $symbol, 'success' } = 1;
        $info{ $symbol, 'symbol' }  = $symbol;
        $info{ $symbol, 'name'}     = $quote->{'name'} if $quote->{'name'}; 
        $info{ $symbol, 'exchange'} = $quote->{'exchange'} if $quote->{'exchange'}; 
        $info{ $symbol, 'currency'} = $quote->{'currency'} if $quote->{'currency'}; 
        $info{ $symbol, 'open' }    = $quote->{'open'} if $quote->{'open'}; 
        $info{ $symbol, 'high' }    = $quote->{'high'} if $quote->{'high'};
        $info{ $symbol, 'low' }     = $quote->{'low'} if $quote->{'low'};
        $info{ $symbol, 'close' }   = $quote->{'close'} if $quote->{'close'};
        $info{ $symbol, 'volume' }  = $quote->{'volume'} if $quote->{'volume'};
        $info{ $symbol, 'method' }  = 'twelvedata';
       
        my $time     = strptime('%s', int($quote->{'timestamp'}));
        my $isodate  = strftime('%F', $time);
        $quoter->store_date( \%info, $symbol, { isodate => $isodate } );
    }

    $ua->agent($agent);

    return wantarray() ? %info : \%info;
}
1;

=head1 NAME

Finance::Quote::TwelveData - Obtain quotes from https://twelvedata.com

=head1 SYNOPSIS

    use Finance::Quote;
    
    $q = Finance::Quote->new('TwelveData', twelvedata => {API_KEY => 'your-twelvedata-api-key'});

    %info = Finance::Quote->fetch("IBM", "AAPL");

=head1 DESCRIPTION

This module fetches information from https://twelvedata.com.

This module is loaded by default on a Finance::Quote object. It's
also possible to load it explicitly by placing "TwelveData" in the argument
list to Finance::Quote->new().

This module provides the "twelvedata" fetch method.

=head1 API_KEY

https://twelvedata.com requires users to register and obtain an API key, which
is a secret value written in hexidecimal.

The API key may be set by either providing a module specific hash to
Finance::Quote->new as in the above example, or by setting the environment
variable TWELVEDATA_API_KEY.

=head2 FREE KEY LIMITS

The TwelveData free key limits usage to:

=over

=item 800 queries per day

=item 8 queries per minute

=back

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::TwelveData :
    symbol name exchange currency isodate currency open high low close

=cut
