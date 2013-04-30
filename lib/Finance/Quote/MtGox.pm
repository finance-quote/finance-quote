# Copyright (C) 2013, Sam Morris <sam@robots.org.uk>
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.

package Finance::Quote::MtGox;

use strict;
use warnings;
use HTTP::Request::Common;
use JSON;
use LWP::UserAgent;
use POSIX;
use URI::Escape;

my @markets = qw/USD EUR JPY CAD GBP CHF RUB AUD SEK DKK HKD PLN CNY SGD THB NZD NOK/;
my @labels = qw/ask bid currency date exchange last method source success symbol time timezone/;

sub methods {
	my %result;
	foreach my $market (@markets) {
		my $lmarket = lc $market;
		$result{"mtgox_$lmarket"} = sub { unshift (@_, $market); goto &mtgox; };
		$result{"bitcoin_$lmarket"} = sub { unshift (@_, $market); goto &mtgox; };
	}
	return %result;
}

sub labels {
	my %result;
	foreach my $market (@markets) {
		my $lmarket = lc $market;
		$result{"mtgox_$lmarket"} = \@labels;
		$result{"bitcoin_$lmarket"} = \@labels;
	}
	return %result;
}

sub mtgox {
	@_ = (@_);
	my $market = shift // die "Missing market";
	my $quoter = shift // die "Missing quoter";
	my @symbols = (@_);

	my %info;
	foreach my $symbol (@symbols) {
		if (exists $info{$symbol,"symbol"}) {
			next;
		}

		$info{$symbol,"success"} = 0;
		$info{$symbol,"source"} = "MtGox";
		$info{$symbol,"symbol"} = $symbol;

		if (length $symbol > 10) {
			$info{$symbol, "errormsg"} = "Symbol too long";
			next;
		}

		my $r = $quoter->user_agent->request(GET sprintf "https://data.mtgox.com/api/2/%s${market}/money/ticker_fast", uri_escape $symbol);
		if (!$r->is_success) {
			$info{$symbol, "errormsg"} = "HTTP failure";
			next;
		} elsif ($r->headers->content_type ne 'application/json') {
			$info{$symbol, 'errormsg'} = 'API failure: unparseable data';
		}
		my $ticker;
		eval {
			$ticker = decode_json ($r->decoded_content);
		}; if ($@) {
			$info{$symbol, 'errormsg'} = "API failure: parse error: $@";
			next;
		}

		if ($ticker->{"result"} ne "success") {
			$info{$symbol, "errormsg"} = "API failure";
			next;
		}

		# last_all gives us the last trade in any currency, converted
		# to the local currency
		if ($ticker->{"data"}{"last_all"}{"currency"} eq $market) {
			$info{$symbol, "last"} = $ticker->{"data"}{"last_all"}{"value"};
		}
		if ($ticker->{"data"}{"buy"}{"currency"} eq $market) {
			$info{$symbol, "bid"} = $ticker->{"data"}{"buy"}{"value"};
		}
		if ($ticker->{"data"}{"sell"}{"currency"} eq $market) {
			$info{$symbol, "ask"} = $ticker->{"data"}{"sell"}{"value"};
		}

		# The ticker data not supply a timestamp. Fetch the latest
		# trade data and use the date from that instead. To avoid a
		# time-consuming transfer, only request trades from the last
		# minute, falling back to requesting more and more, up to 24
		# hours' worth.
		foreach my $cutoff (60, 60*60, 6*60*60, 24*60*60) {
			my $url = sprintf("https://data.mtgox.com/api/2/%s${market}/money/trades/fetch?since=%s", uri_escape($symbol), 1000_000 * (time - $cutoff));
			my $r2 = $quoter->user_agent->request(GET $url);
			if (!$r2->is_success || $r2->headers->content_type ne 'application/json') {
				last;
			}

			my $trades;
			eval {
				$trades = decode_json ($r2->decoded_content);
			}; last if $@;

			if ($trades->{"result"} ne "success") {
				last;
			}

			# If there are no trades, try again. This is the only
			# time we use next, as opposed to last.
			my $last = $trades->{"data"}[-1];
			if (!$last) {
				next;
			}

			if ($last->{"item"} ne $symbol || $last->{"price_currency"} ne $market) {
				last;
			}

			$info{$symbol, "last"} = $last->{"price"};
			my @ts = gmtime $last->{"date"};
			$info{$symbol, "date"} = strftime("%m/%d/%y", @ts);
			$info{$symbol, "time"} = strftime("%H:%M:%S", @ts);
			$info{$symbol, "timezone"} = "UTC";
			last;
		}

		if ($info{$symbol, "last"} || $info{$symbol, "buy"} || $info{$symbol, "sell"}) {
			$info{$symbol, "success"} = 1;
			$info{$symbol, "currency"} = $market;
			$info{$symbol, "exchange"} = "Mt.Gox";
			$info{$symbol, "method"} = sprintf("mtgox_%s", lc $market);
		}
	}
	return wantarray() ? %info : \%info;
}

1;

=head1 NAME

Finance::Quote::MtGox - Obtain information from Mt.Gox

=head1 SYNOPSIS

    use Finance::Quote;
    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("mtgox_usd", "BTC");
    %info = Finance::Quote->fetch("mtgox_eur", "LTC");

=head1 DESCRIPTION

This module fetches information from Mt.Gox. The following symbols are
currently known:

=over

=item BTC: Bitcoin

=item LTC: Litecoin (market not yet operational)

=item NMC: Namecoin (market not yet operational)

=back

The following methods provide prices directly from Mt.Gox, in each of the
currency markets that they operate.

=over

=item mtgox_aud: Australian Dollar

=item mtgox_cad: Canadian Dollar

=item mtgox_chf: Swiss Franc

=item mtgox_cny: Yuan Renminbi

=item mtgox_dkk: Danish Krone

=item mtgox_eur: Euro

=item mtgox_gbp: Pound Sterling

=item mtgox_hkd: Hong Kong Dollar

=item mtgox_jpy: Yen

=item mtgox_nok: Norweigan Krone

=item mtgox_nzd: New Zealand Dollar

=item mtgox_pln: Zloty

=item mtgox_rub: Russian Ruble

=item mtgox_sek: Swedish Kronor

=item mtgox_sgd: Singapore Dollar

=item mtgox_thb: Baht

=item mtgox_usd: US Dollar

=back

In addition, "bitcoin_$market" methods are provided in case failover to other
exchanges is desirable. These methods will return data for other digital
currencies than Bitcoin; the currency for which data is retrieved is determined
by the symbol name passed to the method.

Mt.Gox operates a multi-currency market, where all offers across all markets
are amalgamated into a common pool. Trades between markets are matched using
the European Central Bank's daily exchange rate, plus a 2.5% fee included in
the price.

=head1 LABELS RETURNED

=over

=item ask: lowest asking price

=item bid: highest offer price

=item currency: currency of retrieved quote

=item date, time: time of last trade

=item exchange: always 'Mt.Gox'

=item last: last trade price

=item method: fetching method used

=item timezone: always UTC

=back

