#!/usr/bin/perl -w
#
# Offline tests for the FedInvest XML parse and the price ladder. No network:
# the documents below are trimmed from a real file so the cases that matter can
# be pinned without depending on what the Treasury happens to publish today.

use strict;
use Test::More;
use Finance::Quote::TreasuryDirect;

plan tests => 18;

# A note quoted on both sides, a bill quoted on one side only, a record from a
# completed day where EODPrice is filled in, and one with nothing usable.
my $xml = <<'END_XML';
<?xml version="1.0" encoding="ISO-8859-1"?>
<bpd:FedInvestPriceData xmlns:bpd="http://www.treasurydirect.gov/">
<Prices>
	<Security>
		<PriceDate>2026-09-02</PriceDate>
		<Cusip>912810QT8</Cusip>
		<SecurityType>MARKET BASED BOND</SecurityType>
		<Rate>0.03125</Rate>
		<MaturityDate>11/15/2041</MaturityDate>
		<CallDate></CallDate>
		<BuyPrice>78.890625</BuyPrice>
		<SellPrice>78.843750</SellPrice>
		<EODPrice>0.000000</EODPrice>
	</Security>
	<Security>
		<PriceDate>2026-09-02</PriceDate>
		<Cusip>912797RS8</Cusip>
		<SecurityType>MARKET BASED BILL</SecurityType>
		<Rate>0.0</Rate>
		<MaturityDate>09/03/2026</MaturityDate>
		<CallDate></CallDate>
		<BuyPrice>0.000000</BuyPrice>
		<SellPrice>99.989972</SellPrice>
		<EODPrice>0.000000</EODPrice>
	</Security>
	<Security>
		<PriceDate>2026-08-31</PriceDate>
		<Cusip>912797UW5</Cusip>
		<SecurityType>MARKET BASED BILL</SecurityType>
		<Rate>0.0</Rate>
		<MaturityDate>09/22/2026</MaturityDate>
		<CallDate></CallDate>
		<BuyPrice>0.000000</BuyPrice>
		<SellPrice>0.000000</SellPrice>
		<EODPrice>100.000000</EODPrice>
	</Security>
	<Security>
		<PriceDate>2026-09-02</PriceDate>
		<Cusip>000000000</Cusip>
		<SecurityType>NOTHING QUOTED</SecurityType>
		<Rate>0.0</Rate>
		<MaturityDate>01/01/2030</MaturityDate>
		<CallDate></CallDate>
		<BuyPrice>0.000000</BuyPrice>
		<SellPrice>0.000000</SellPrice>
		<EODPrice>0.000000</EODPrice>
	</Security>
</Prices>
</bpd:FedInvestPriceData>
END_XML

my $bonds = Finance::Quote::TreasuryDirect::parse_prices($xml);

ok( defined $bonds, 'parse returns a hashref' );
is( scalar keys %{$bonds}, 4, 'all four securities parsed' );

# FedInvest publishes BUY as what an investor pays and SELL as what they
# receive, so BuyPrice is the ask and SellPrice is the bid.
is( $bonds->{'912810QT8'}{ask}, '78.890625', 'ask comes from BuyPrice' );
is( $bonds->{'912810QT8'}{bid}, '78.843750', 'bid comes from SellPrice' );
cmp_ok( $bonds->{'912810QT8'}{ask}, '>=', $bonds->{'912810QT8'}{bid},
        'ask is not below bid' );

is( $bonds->{'912810QT8'}{maturity}, '11/15/2041', 'maturity parsed' );
is( $bonds->{'912810QT8'}{rate}, '0.03125', 'rate is the raw decimal fraction' );

# Two-sided: the mean of the two quotes.
is( Finance::Quote::TreasuryDirect::price_from( $bonds->{'912810QT8'} ),
    '78.867188', 'two-sided price is the mean' );

# One-sided: the quoted side, NOT the mean of it and a zero. This is the
# regression the module exists to prevent - the mean would be 49.994986.
is( Finance::Quote::TreasuryDirect::price_from( $bonds->{'912797RS8'} ),
    '99.989972', 'one-sided price is the quoted side, not half of it' );
cmp_ok( Finance::Quote::TreasuryDirect::price_from( $bonds->{'912797RS8'} ),
        '>', 90, 'one-sided price is not halved' );

# Neither side quoted, but the day is complete: fall back to the close.
is( Finance::Quote::TreasuryDirect::price_from( $bonds->{'912797UW5'} ),
    '100.000000', 'falls back to EODPrice when neither side is quoted' );

# Nothing usable at all.
is( Finance::Quote::TreasuryDirect::price_from( $bonds->{'000000000'} ),
    undef, 'no usable price returns undef' );

# A day with no prices - a weekend or a holiday - is an empty document, not a
# broken one, and must be distinguishable from a parse failure.
my $empty = <<'END_EMPTY';
<?xml version="1.0" encoding="ISO-8859-1"?>
<bpd:FedInvestPriceData xmlns:bpd="http://www.treasurydirect.gov/">
<Prices>
</Prices>
</bpd:FedInvestPriceData>
END_EMPTY

my $none = Finance::Quote::TreasuryDirect::parse_prices($empty);
ok( defined $none, 'an empty document still parses' );
is( scalar keys %{$none}, 0, 'and yields no securities' );

# A document that will not parse is a different thing again.
is( Finance::Quote::TreasuryDirect::parse_prices('<not xml'), undef,
    'malformed input returns undef' );

# Comments and processing instructions inside a Security must not become
# fields; localname is undef on those nodes.
my $commented = $xml;
$commented =~ s{<Cusip>912810QT8</Cusip>}{<!-- a comment --><Cusip>912810QT8</Cusip>};
my $ok = Finance::Quote::TreasuryDirect::parse_prices($commented);
ok( defined $ok, 'a document containing comments parses' );
is( $ok->{'912810QT8'}{ask}, '78.890625', 'and its fields are unaffected' );
is( scalar keys %{$ok}, 4, 'and no security is lost' );
