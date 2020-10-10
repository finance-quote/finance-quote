#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if ( not $ENV{"ONLINE_TEST"} ) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

if ( not $ENV{"TEST_ALPHAVANTAGE_API_KEY"} ) {
    plan skip_all =>
        'Set $ENV{TEST_ALPHAVANTAGE_API_KEY} to run this test; get one at https://www.alphavantage.co';
}

my $q        = Finance::Quote->new('AlphaVantage', 'alphavantage' => {'API_KEY' => $ENV{"TEST_ALPHAVANTAGE_API_KEY"}} );
my $year     = ( localtime() )[5] + 1900;
my $lastyear = $year - 1;

my @symbols =  qw/
    IBM
    CSCO
    SOLB.BR
    SAP.DE
    TD.TO
    LSE.L
    VFIAX
    T
    DIVO11.SA
    TWTR
    AAPL
    ORCL
    FB
    CMCSA
    INTC
    NFLX
    TSLA
    NOK
    BAC
    GOOG
    F
    AXP
    ERCB.DE
/;

plan tests => 11*(1+$#symbols)+10;

my %quotes = $q->alphavantage( @symbols, "BOGUS" );
ok(%quotes);

foreach my $symbol (@symbols) {
    ok( $quotes{ $symbol, "success" }, "$symbol success" );
    ok( $quotes{ $symbol, "symbol" } eq $symbol , "$symbol defined" );
    ok( $quotes{ $symbol, "open" } > 0, "$symbol returned open" );
    ok( $quotes{ $symbol, "close" } > 0, "$symbol returned close" );
    ok( $quotes{ $symbol, "last" } > 0, "$symbol returned last" );
    ok( $quotes{ $symbol, "high" } > 0, "$symbol returned high" );
    ok( $quotes{ $symbol, "low" } > 0, "$symbol returned low" );
    ok( $quotes{ $symbol, "volume" } >= 0, "$symbol returned volume" );
    ok( $quotes{ $symbol, "p_change" } =~ /^[\-\.\d]+$/, "$symbol returned p_change" );
    ok(    substr( $quotes{ $symbol, "isodate" }, 0, 4 ) == $year
               || substr( $quotes{ $symbol, "isodate" }, 0, 4 ) == $lastyear );
    ok(    substr( $quotes{ $symbol, "date" }, 6, 4 ) == $year
               || substr( $quotes{ $symbol, "date" }, 6, 4 ) == $lastyear );
}

is( $quotes{ "IBM", "currency" }, 'USD' );
is( $quotes{ "CSCO", "currency" }, 'USD' );
is( $quotes{ "ERCB.DE", "currency" }, 'EUR' );
is( $quotes{ "SOLB.BR", "currency" }, 'EUR' );
is( $quotes{ "SAP.DE", "currency" }, 'EUR' );
is( $quotes{ "TD.TO", "currency" }, 'CAD' );
is( $quotes{ "LSE.L", "currency" }, 'GBP' );
is( $quotes{ "DIVO11.SA", "currency" }, 'BRL' );

ok( !$quotes{ "BOGUS", "success" } );
