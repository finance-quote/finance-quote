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
use URI::Escape;

my @markets = qw/USD EUR JPY CAD GBP CHF RUB AUD SEK DKK HKD PLN CNY SGD THB NZD NOK/;
my @labels = ("last", "bid", "ask");

sub methods {
	my %result;
	foreach my $market (@markets) {
		my $lmarket = lc $market;
		$result{"mtgox_$lmarket"} = sub { mtgox ($market, @_) };
		$result{"bitcoin_$lmarket"} = sub { mtgox ($market, @_) };
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
	my $market = shift // "Missing market";
	my $quoter = shift // "Missing quoter";
	my @currencies = (@_);

	my $ua = $quoter->user_agent();
	$ua->max_size (1024);

	my %data;

	my %info;
	foreach my $currency (@currencies) {
		$info{$currency, "source"} = "MtGox";
		$info{$currency, "success"} = 0;

		if (!exists $data{$currency}) {
			if (length $currency > 10) {
				$info{$currency, "errormsg"} = "Symbol too long";
				next;
			}
			my $r = $ua->request(GET sprintf "https://data.mtgox.com/api/2/%s${market}/money/ticker_fast", uri_escape $currency);
			if ($r->is_success) {
				$data{$currency} = decode_json ($r->decoded_content);
			} else {
				$info{$currency, "errormsg"} = "HTTP failure";
				next;
			}
		}

		if ($data{$currency}->{"result"} ne "success") {
			$info{$currency, "errormsg"} = "API failure";
			next;
		}

		$info{$currency, "success"} = 1;
		# last_all gives us the last trade in any currency, converted to the local currency
		$info{$currency, "last"} = $data{$currency}->{"data"}{"last_all"}{"value"};
		$info{$currency, "bid"} = $data{$currency}->{"data"}{"buy"}{"value"};
		$info{$currency, "ask"} = $data{$currency}->{"data"}{"sell"}{"value"};
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
the offer price.

=head1 LABELS RETURNED

=over

=item last: last trade price

=item bid: highest offer

=item ask: lowest asking price

=back

