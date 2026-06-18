#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if ( not $ENV{"ONLINE_TEST"} ) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

if ( not $ENV{"TEST_FINNHUB_API_KEY"} ) {
    plan skip_all =>
        'Set $ENV{TEST_FINNHUB_API_KEY} to run this test; get a free key at https://finnhub.io';
}

my $q        = Finance::Quote->new('Finnhub', 'finnhub' => {'API_KEY' => $ENV{"TEST_FINNHUB_API_KEY"}} );
my $year     = ( localtime() )[5] + 1900;
my $lastyear = $year - 1;

# AAPL, MSFT: US equities (currency/name from company profile)
# SPY: ETF (no company profile; currency defaults to USD)
my @symbols = qw/AAPL MSFT SPY/;

plan tests => 1 + 6*(1+$#symbols) + 1;

my %quotes = $q->fetch( 'finnhub', @symbols, "BOGUS" );
ok(%quotes);

foreach my $symbol (@symbols) {
    ok( $quotes{ $symbol, "success" }, "$symbol success" );
    ok( $quotes{ $symbol, "symbol" } eq $symbol, "$symbol defined" );
    ok( $quotes{ $symbol, "last" } > 0, "$symbol returned last" );
    ok( $quotes{ $symbol, "currency" } eq 'USD', "$symbol currency USD" );
    ok( $quotes{ $symbol, "method" } eq 'finnhub', "$symbol method" );
    ok(    substr( $quotes{ $symbol, "isodate" }, 0, 4 ) == $year
               || substr( $quotes{ $symbol, "isodate" }, 0, 4 ) == $lastyear,
           "$symbol isodate in current or last year" );
}

ok( !$quotes{ "BOGUS", "success" }, 'BOGUS failed as expected' );
