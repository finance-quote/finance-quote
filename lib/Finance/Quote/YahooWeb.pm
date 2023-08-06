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
use HTML::TableExtract;
use HTML::TreeBuilder::XPath;
use Text::Template;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

# VERSION

my $URL   = Text::Template->new(TYPE => 'STRING', SOURCE => 'https://finance.yahoo.com/quote/{$symbol}/history?p={$symbol}');
my $AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/113.0.0.0 Safari/537.36';
my $XPATH = Text::Template->new(TYPE => 'STRING', SOURCE => '//*[@data-symbol=~"^{$symbol}$"][@data-field=~"regularMarketPrice"]');

sub features() {
    return {'description' => 'Fetch quotes from Yahoo Finance through Web Interface'};
}

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
    my ( %info, $url, $reply );
    my $ua = $quoter->user_agent();
    my $agent = $ua->agent();
    $ua->agent($AGENT);

    foreach my $symbol (@stocks) {
        $url   = $URL->fill_in(HASH => {symbol => $symbol});
        $reply = $ua->request(GET $url);

        ### YahooWeb: $url
        unless ($reply->is_success) {
            $info{ $symbol, "success" } = 0;
            $info{ $symbol, "errormsg" } = join ' ', $reply->code, $reply->message;
            next; 
        }
       
        my $tree = HTML::TreeBuilder::XPath->new();
        $tree->ignore_unknown(0);
        $tree->parse($reply->decoded_content);

        my ($name, $yahoo_symbol) = map { $_ =~ /^(.+) \(([^)]+)\)/ ? ($1, $2) : () } $tree->findnodes_as_strings('//*[@id="quote-header-info"]//div//h1');
        
        if (uc($symbol) ne uc($yahoo_symbol)) {
            ### Error: $symbol, $yahoo_symbol
            $info{ $symbol, "success" } = 0;
            $info{ $symbol, "errormsg" } = 'Unexpected response from Yahoo site';
            next; 
        }

        $info{ $symbol, 'name' } = $name;

        my ($exchange, $currency) = map { $_ =~ /^(.+)[.] Currency in (.+)$/ ? ($1, $2) : () } $tree->findnodes_as_strings('//*[@id="quote-header-info"]//div//span');
        $info{ $symbol, 'exchange' } = $exchange;
        if ($currency =~ /^GBp/) {
            $info{ $symbol, 'currency' } = 'GBP';
        } else {
            $info{ $symbol, 'currency' } = $currency;
        }

        my $te = HTML::TableExtract->new(
            headers => ['Date', 'Open', 'High', 'Low', 'Close\*', 'Adj Close\*\*', 'Volume'],
            attribs => { 'data-test' => "historical-prices" } );
        unless ($te->parse($reply->decoded_content)) {
            $info{ $symbol, "success" } = 0;
            $info{ $symbol, "errormsg" } = "YahooWeb - History table not found.";
            next;
        }
        my $historytable = $te->first_table_found();
        # Find a row with a price
        my $row = 0;
        foreach my $r ($historytable->rows) {
            if (defined $historytable->cell($row, 4) &&
                $historytable->cell($row, 4) ne "-") {
                last;
            }
            $row += 1;
        } 
        my $rows = $historytable->rows(); 
        ### Row count: scalar @$rows
        ### Index: $row
        if ($row >= @$rows) {
            $info{ $symbol, "success" } = 0;
            $info{ $symbol, "errormsg" } = "YahooWeb - no row with a price.";
            next;
        }
        ### Row: $historytable->row($row)
        my ($month, $day, $year) = $historytable->cell($row,0)
            =~ m|(\w+) (\d+), (\d{4})|;
        ### Month: $month
        ### Day: $day
        ### Year: $year

        my $last = $historytable->cell($row,4);
        $last =~ s/,//g;
        if ($currency =~ /^GBp/) {
            $last = $last / 100;
        }

        my $open = $historytable->cell($row,1);
        $open =~ s/,//g;
        if ($currency =~ /^GBp/) {
            $open = $open / 100;
        }

        my $high = $historytable->cell($row,2);
        $high =~ s/,//g;
        if ($currency =~ /^GBp/) {
            $high = $high / 100;
        }

        my $low = $historytable->cell($row,3);
        $low =~ s/,//g;
        if ($currency =~ /^GBp/) {
            $low = $low / 100;
        }

        my $volume = $historytable->cell($row,6);
        $volume =~ s/,//g;

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
