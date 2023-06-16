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

use Date::Business;
use HTTP::Request::Common;
use HTML::TreeBuilder::XPath;
use Text::Template;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

# VERSION

my $URL   = Text::Template->new(TYPE => 'STRING', SOURCE => 'https://finance.yahoo.com/quote/{$symbol}?p={$symbol}');
my $AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/113.0.0.0 Safari/537.36';
my $XPATH = Text::Template->new(TYPE => 'STRING', SOURCE => '//*[@data-symbol=~"{$symbol}"][@data-field=~"regularMarketPrice"]');

sub methods { 
    return ( yahooweb => \&yahooweb );
}

{
    our @labels = qw/symbol name exchange currency isodate last/;

    sub labels {
        return ( yahooweb => \@labels );
    }
}

# Needed for Date::Business
sub holiday($$) {
  my ($start, $end) = @_;

  my ($numHolidays) = 0;
  my ($holiday, @holidays);

  # Get Stock Exchange holidays at
  # https://www.nyse.com/markets/hours-calendars
  # 2023
  push @holidays, '20230619';
  push @holidays, '20230704';
  push @holidays, '20230904';
  push @holidays, '20231123';
  push @holidays, '20231225';

  # 2024
  push @holidays, '20240101';
  push @holidays, '20240115';
  push @holidays, '20240219';
  push @holidays, '20240329';
  push @holidays, '20240527';
  push @holidays, '20240619';
  push @holidays, '20240704';
  push @holidays, '20240902';
  push @holidays, '20241128';
  push @holidays, '20241225';

  # 2025
  push @holidays, '20250101';
  push @holidays, '20250120';
  push @holidays, '20250217';
  push @holidays, '20250418';
  push @holidays, '20250526';
  push @holidays, '20250619';
  push @holidays, '20250704';
  push @holidays, '20250901';
  push @holidays, '20251127';
  push @holidays, '20251225';

  foreach $holiday (@holidays) {
    $numHolidays++ if ($start le $holiday && $end ge $holiday);
  }
  return $numHolidays;
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
            $info{ $symbol, "errmsg" } = join ' ', $reply->code, $reply->message;
            next; 
        }
       
        my $tree = HTML::TreeBuilder::XPath->new();
        $tree->ignore_unknown(0);
        $tree->parse($reply->decoded_content);

        my ($name, $yahoo_symbol) = map { $_ =~ /^(.+) \(([^)]+)\)/ ? ($1, $2) : () } $tree->findnodes_as_strings('//*[@id="quote-header-info"]//div//h1');
        
        if (uc($symbol) ne uc($yahoo_symbol)) {
            ### Error: $symbol, $yahoo_symbol
            $info{ $symbol, "success" } = 0;
            $info{ $symbol, "errmsg" } = 'Unexpected response from Yahoo site';
            next; 
        }

        $info{ $symbol, 'name' } = $name;

        my ($exchange, $currency) = map { $_ =~ /^(.+)[.] Currency in (.+)$/ ? ($1, $2) : () } $tree->findnodes_as_strings('//*[@id="quote-header-info"]//div//span');
        $info{ $symbol, 'exchange' } = $exchange;
        $info{ $symbol, 'currency' } = $currency;

        my $xpath = $XPATH->fill_in(HASH => {symbol => $symbol});
        my $last = $tree->findvalue($xpath);
        $last =~ s/,//g;

        ### YahooWeb Result: $xpath, $last
        $info{ $symbol, 'last'} = $last;

        # Use Date::Business to get last business day
        my $d = Date::Business->new(FORCE => 'prev', HOLIDAY => \&holiday);

        # date, isodate
        $quoter->store_date(\%info, $symbol, {isodate => $d->image()});   
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
    symbol name exchange currency isodate last

=cut
