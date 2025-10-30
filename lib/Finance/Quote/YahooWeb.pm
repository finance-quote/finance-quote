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

use Encode qw( encode_utf8 );
use HTTP::Request::Common;
use HTML::TreeBuilder::XPath;
use JSON qw( decode_json );
use LWP::Protocol::http;
use Text::Template;
use HTTP::Cookies;
use URI::Escape;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use constant URLTAG => "data-url";
use constant JSONBODY => "body";

# VERSION

# Fix for 500 Header line too long message
push(@LWP::Protocol::http::EXTRA_SOCK_OPTS, MaxLineLength => 0);

my $URL   = Text::Template->new(TYPE => 'STRING', SOURCE => 'https://finance.yahoo.com/quote/{$symbol}/history?p={$symbol}&crumb={$crumb}');
# my $AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.95 Safari/537.36';
my $AGENT = 'Mozilla/5.0';
my $XPATH = Text::Template->new(TYPE => 'STRING', SOURCE => '//*[@data-symbol=~"^{$symbol}$"][@data-field=~"regularMarketPrice"]');

our $DISPLAY    = '<Module Name + Brief Info>';
our @LABELS     = qw/symbol name exchange currency isodate last open high low volume/;
our $METHODHASH = {subroutine => \&yahooweb, 
                   display => $DISPLAY, 
                   labels => \@LABELS};

sub methodinfo {
    return ( 
        yahooweb => $METHODHASH,
    );
}

sub labels {
  my %m = methodinfo();
  return map {$_ => [@{$m{$_}{labels}}] } keys %m;
}

sub methods {
  my %m = methodinfo(); return map {$_ => $m{$_}{subroutine} } keys %m;
}

sub yahooweb {
    my $quoter = shift;

    my @stocks = @_;
    my ( %info, $url, $reply, $script_tag );
    my $ua = $quoter->user_agent();
    my $agent = $ua->agent();

    my $cookie_jar = HTTP::Cookies->new;

    # Redirect handler deals with cookie consent workflow applicable to EU countries
    # credit to John Weber from Germany for injecting redirect handler
    my $gcrumb = "";
    $ua->add_handler("response_redirect", sub {
        my($response, $ua, $h) = @_;

        # Check where we've been redirected and act accordingly
        my $redirect_uri = URI->new($response->header("Location"));
        if ($redirect_uri->path eq "/consent") {

            # Remember gcrumb value for collectConsent request later
            my %params = $redirect_uri->query_form;
            $gcrumb = $params{'gcrumb'};

        } elsif ($redirect_uri->path eq "/v2/collectConsent") {

            my %params = $redirect_uri->query_form;
            my $sessionId = $params{'sessionId'};

            # Turn this request into a POST with form data to confoo accept cookies
            my $request = POST($redirect_uri, [
                'csrfToken' => $gcrumb,
                'sessionId' => $sessionId,
                'originalDoneUrl' => 'https://www.yahoo.com/?guccounter=1',
                'namespace' => 'yahoo',
            # For the EU consent, either can :
            #   'agree' => 'agree'
            # to it or
                'reject' => 'reject'
            ]);
            return $request;
        }
        return;
    });

    $ua->cookie_jar($cookie_jar);
    $ua->agent($AGENT);

    # Tell user agent to redirect POSTs in additional to GET AND HEAD
    $ua->requests_redirectable(['GET', 'HEAD', 'POST']);

    # get necessary cookies
    $reply = $ua->get('https://www.yahoo.com/', "Accept" => "text/html");

    if ($reply->code != 200) {
        foreach my $symbol (@stocks) {
            $info{$symbol, "success"} = 0;
            $info{$symbol, "errormsg"} = "Error accessing www.yahoo.com: $@";
        }     
        return wantarray() ? %info : \%info;
    }

    # get the crumb that corrosponds to cookies retrieved
    $reply = $ua->request(GET 'https://query2.finance.yahoo.com/v1/test/getcrumb');
    if ($reply->code != 200) {
        foreach my $symbol (@stocks) {
            $info{$symbol, "success"} = 0;
            $info{$symbol, "errormsg"} = "Error accessing queary.finance.yahoo.com/v1/test/getcrumb: $@";
        }     
        return wantarray() ? %info : \%info;
    }
    my $crumb = uri_escape($reply->content);

    ### [<now>]    cookie_jar : $cookie_jar
    ### [<now>]         crumb : $crumb

    foreach my $symbol (@stocks) {
        $url   = $URL->fill_in(HASH => {symbol => $symbol, crumb => $crumb});

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
        eval {$json_data = decode_json encode_utf8( $numfound[0] )};
        if($@) {
            $info{ $symbol, 'success' } = 0;
            $info{ $symbol, 'errormsg' } = $@;
            next;
        }

        ### [<now>] json_data: $json_data

        my $json_body =
            encode_utf8($json_data->{'body'});
        ### [<now>] json_body: $json_body;

        eval {$json_data = decode_json $json_body};
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
        if ($open) {
            $open =~ s/,//g;
            if ($currency =~ /^GBp/) {
                $open = $open / 100;
            }
        }

        my $high = $json_data->{'quoteResponse'}{'result'}[0]{'regularMarketDayHigh'}{'fmt'};
        if ($high) {
            $high =~ s/,//g;
            if ($currency =~ /^GBp/) {
                $high = $high / 100;
            }
        }

        my $low = $json_data->{'quoteResponse'}{'result'}[0]{'regularMarketDayLow'}{'fmt'};
        if ($low) {
            $low =~ s/,//g;
            if ($currency =~ /^GBp/) {
                $low = $low / 100;
            }
        }

        my $volume = $json_data->{'quoteResponse'}{'result'}[0]{'regularMarketVolume'}{'raw'};
        $volume =~ s/,//g if $volume;

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
