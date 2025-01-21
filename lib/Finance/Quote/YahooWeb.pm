# vi: set noai ic ts=4 sw=4 showmode showmatch:  
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

package Finance::Quote::YahooWeb;

use warnings;
use strict;

use HTTP::Request::Common;
use HTML::TreeBuilder::XPath;
use JSON qw( decode_json );
use LWP::Protocol::http;
use Text::Template;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use constant URLTAG => "data-url";
use constant JSONBODY => "body";

# VERSION

# Fix for 500 Header line too long message
push(@LWP::Protocol::http::EXTRA_SOCK_OPTS, MaxLineLength => 0);

my $URL   = Text::Template->new(TYPE => 'STRING', SOURCE => 'https://finance.yahoo.com/quote/{$symbol}/history?p={$symbol}');
my $AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/113.0.0.0 Safari/537.36';
my $XPATH = Text::Template->new(TYPE => 'STRING', SOURCE => '//*[@data-symbol=~"^{$symbol}$"][@data-field=~"regularMarketPrice"]');

sub methods { 
    return ( yahooweb => \&yahooweb );
}

{
    our @labels =
        qw/symbol name exchange currency isodate last open high low volume/;

    sub labels {
        return ( yahooweb => \@labels );
    }
}

sub yahooweb {
    my $quoter = shift;

    my @stocks = @_;
    my ( %info, $url, $reply, $script_tag );
    my $ua = $quoter->user_agent();
    my $agent = $ua->agent();
    $ua->agent($AGENT);

    foreach my $symbol (@stocks) {
        $url   = $URL->fill_in(HASH => {symbol => $symbol});

        ### [<now>] YahooWeb: $url
        $reply = $ua->request(GET $url);

        ### [<now>] Reply: $reply

        unless ($reply->is_success) {
            $info{ $symbol, "success" } = 0;
            $info{ $symbol, "errormsg" } = join ' ', $reply->code, $reply->message;
            next; 
        }
       
        my $tree = HTML::TreeBuilder::XPath->new();
        $tree->ignore_unknown(0);
        $tree->parse($reply->decoded_content);

        $script_tag = $tree->look_down(_tag => 'script', type => 'application/json', URLTAG, qr!https://query1.finance.yahoo.com/v7/finance/quote\?fields=fiftyTwoWeekHigh.*! );

        ### [<now>] script_tag: $script_tag

        unless($script_tag) {
            $info{ $symbol, "success" } = 0;
            $info{ $symbol, "errormsg" } = 'Error - Symbol not found';
            next;
        }

        my @numfound = $script_tag->content_list();

        ### [<now>] numfound: @numfound

        my $json_data;
        eval {$json_data = JSON::decode_json $numfound[0]};
        if($@) {
            $info{ $symbol, 'success' } = 0;
            $info{ $symbol, 'errormsg' } = $@;
            next;
        }

        ### [<now>] json_data: $json_data

        my $json_body =
            $json_data->{'body'};
        ### [<now>] json_body: $json_body;

        eval {$json_data = JSON::decode_json $json_body};
        if($@) {
            $info{ $symbol, 'success' } = 0;
            $info{ $symbol, 'errormsg' } = $@;
            next;
        }

        ### [<now>] json_data 2: $json_data

        my $yahoo_symbol =
            $json_data->{'quoteResponse'}{'result'}[0]{'symbol'};

        my $name = $json_data->{'quoteResponse'}{'result'}[0]{'shortName'};
        
        if (uc($symbol) ne uc($yahoo_symbol)) {
            ### Error: $symbol, $yahoo_symbol
            $info{ $symbol, "success" } = 0;
            $info{ $symbol, "errormsg" } = 'Unexpected response from Yahoo site';
            next; 
        }

        $info{ $symbol, 'name' } = $name if $name;
        my $currency = $json_data->{'quoteResponse'}{'result'}[0]{'currency'};
        $info{ $symbol, 'currency' } = $currency if $currency;
        $info{ $symbol, 'exchange' } = 
            $json_data->{'quoteResponse'}{'result'}[0]{'fullExchangeName'};

        if ($currency =~ /^GBp/) {
            $info{ $symbol, 'currency' } = 'GBP';
        } else {
            $info{ $symbol, 'currency' } = $currency;
        }

        my $last = $json_data->{'quoteResponse'}{'result'}[0]{'regularMarketPrice'}{'fmt'};
        $last =~ s/,//g;
        if ($currency =~ /^GBp/) {
            $last = $last / 100;
        }

        my $open = $json_data->{'quoteResponse'}{'result'}[0]{'regularMarketOpen'}{'fmt'};
        $open =~ s/,//g;
        if ($currency =~ /^GBp/) {
            $open = $open / 100;
        }

        my $high = $json_data->{'quoteResponse'}{'result'}[0]{'regularMarketDayHigh'}{'fmt'};
        $high =~ s/,//g;
        if ($currency =~ /^GBp/) {
            $high = $high / 100;
        }

        my $low = $json_data->{'quoteResponse'}{'result'}[0]{'regularMarketDayLow'}{'fmt'};
        $low =~ s/,//g;
        if ($currency =~ /^GBp/) {
            $low = $low / 100;
        }

        my $volume = $json_data->{'quoteResponse'}{'result'}[0]{'regularMarketVolume'}{'raw'};
        $volume =~ s/,//g;

        # regularMarketTime in JSON is seconds since epoch
        my $tradedate = $json_data->{'quoteResponse'}{'result'}[0]{'regularMarketTime'}{'raw'};
        my (undef,undef,undef,$day,$month,$year,undef,undef,undef) = localtime($tradedate);
        $month += 1;
        $year += 1900;

        ### YahooWeb Result: $last
        $info{ $symbol, 'last'} = $last;
        $info{ $symbol, 'open'} = $open;
        $info{ $symbol, 'high'} = $high;
        $info{ $symbol, 'low'} = $low;
        $info{ $symbol, 'volume'} = $volume unless $volume eq "-";

        $quoter->store_date(\%info, $symbol, {month => $month, day => $day, year => $year});   
        $info{ $symbol, 'symbol' } = $symbol;
        $info{ $symbol, 'method' } = 'yahooweb';
        $info{ $symbol, 'success' } = 1;
    }
    $ua->agent($agent);
    return wantarray ? %info : \%info;
}
1;

=head1 NAME

Finance::Quote::YahooWeb - Obtain quotes from https://finance.yahoo.com/quote 

=head1 SYNOPSIS

    use Finance::Quote;
    $q = Finance::Quote->new('YahooWeb');
    %info = $q->fetch('yahooweb', "IBM", "AAPL");

=head1 DESCRIPTION

This module fetches information from https://finance.yahoo.com/quote.

This module is loaded by default on a Finance::Quote object. It's
also possible to load it explicitly by placing "YahooWeb" in the argument
list to Finance::Quote->new().

This module provides the "yahooweb" fetch method.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::YahooWeb :
    symbol name exchange currency isodate last open high low volume

=cut
