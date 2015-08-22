#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if ( not $ENV{ONLINE_TEST} ) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 46;

# Test GoldMoney functions.
my $q = Finance::Quote->new("GoldMoney");

foreach my $currency ( 'EUR', 'USD' ) {
    $q->set_currency($currency);
    my %quotes =
        $q->fetch( "goldmoney", "gold", "silver", "platinum", "BOGUS" );
    ok(%quotes);

    # Check that sound information is returned for gold, silver and platinum.
    ok( $quotes{ "gold", "success" }, 'gold price lookup' );
    ok( $quotes{ "gold", "last" } > 0,
        "Gold is quoted at " . $quotes{ "gold", "last" } );
    ok( $quotes{ "gold", "currency" } eq $currency, "currency is $currency" );
    ok( length( $quotes{ "gold", "date" } ) > 0 );
    ok( length( $quotes{ "gold", "time" } ) > 0 );

    ok( $quotes{ "silver", "success" },               'silver price lookup' );
    ok( $quotes{ "silver", "last" } > 0 );
    ok( $quotes{ "silver", "currency" } eq $currency, "currency is $currency" );
    ok( length( $quotes{ "silver", "date" } ) > 0 );
    ok( length( $quotes{ "silver", "time" } ) > 0 );

    ok( $quotes{ "platinum", "success" }, 'platinum price lookup' );
    ok( $quotes{ "platinum", "last" } > 0 );
    ok( $quotes{ "platinum", "currency" } eq $currency,
        "currency is $currency" );
    ok( length( $quotes{ "platinum", "date" } ) > 0 );
    ok( length( $quotes{ "platinum", "time" } ) > 0 );

    my $year = ( localtime() )[5] + 1900;
    ok( ( substr( $quotes{ "gold",     "isodate" }, 0, 4 ) == $year ) );
    ok( ( substr( $quotes{ "gold",     "date" },    6, 4 ) == $year ) );
    ok( ( substr( $quotes{ "silver",   "isodate" }, 0, 4 ) == $year ) );
    ok( ( substr( $quotes{ "silver",   "date" },    6, 4 ) == $year ) );
    ok( ( substr( $quotes{ "platinum", "isodate" }, 0, 4 ) == $year ) );
    ok( ( substr( $quotes{ "platinum", "date" },    6, 4 ) == $year ) );

    # Check that a bogus symbol returns no-success.
    ok( !$quotes{ "BOGUS", "success" } );
}
