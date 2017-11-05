#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if ( not $ENV{"ONLINE_TEST"} ) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

if ( not $ENV{"ALPHAVANTAGE_API_KEY"} ) {
    plan skip_all =>
        'Set $ENV{ALPHAVANTAGE_API_KEY} to run this test; get one at https://www.alphavantage.co';
}

plan tests => 14;

my $q        = Finance::Quote->new();
my $year     = ( localtime() )[5] + 1900;
my $lastyear = $year - 1;

my %quotes = $q->alphavantage( "IBM", "CSCO", "BOGUS" );
ok(%quotes);

ok( $quotes{ "IBM", "success" } );
ok( $quotes{ "IBM", "open" } > 0 );
ok( $quotes{ "IBM", "close" } > 0 );
ok( $quotes{ "IBM", "high" } > 0 );
ok( $quotes{ "IBM", "low" } > 0 );
ok( $quotes{ "IBM", "volume" } > 0 );
ok(    substr( $quotes{ "IBM", "isodate" }, 0, 4 ) == $year
    || substr( $quotes{ "IBM", "isodate" }, 0, 4 ) == $lastyear );
ok(    substr( $quotes{ "IBM", "date" }, 6, 4 ) == $year
    || substr( $quotes{ "IBM", "date" }, 6, 4 ) == $lastyear );

ok( $quotes{ "CSCO", "success" } );
ok( $quotes{ "CSCO", "open" } > 0 );
ok( $quotes{ "CSCO", "close" } > 0 );
ok( $quotes{ "CSCO", "volume" } > 0 );

ok( !$quotes{ "BOGUS", "success" } );
