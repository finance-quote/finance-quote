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

my $q        = Finance::Quote->new();
my $year     = ( localtime() )[5] + 1900;
my $lastyear = $year - 1;

my @symbols =  qw/ IBM CSCO SOLB.BR LSE.L /;

plan tests => 10*(1+$#symbols)+6;

my %quotes = $q->alphavantage( @symbols, "BOGUS" );
ok(%quotes);

foreach my $symbol (@symbols) {
    ok( $quotes{ $symbol, "success" } );
    ok( $quotes{ $symbol, "symbol" } eq $symbol );
    ok( $quotes{ $symbol, "open" } > 0 );
    ok( $quotes{ $symbol, "close" } > 0 );
    ok( $quotes{ $symbol, "last" } > 0 );
    ok( $quotes{ $symbol, "high" } > 0 );
    ok( $quotes{ $symbol, "low" } > 0 );
    ok( $quotes{ $symbol, "volume" } > 0 );
    ok(    substr( $quotes{ $symbol, "isodate" }, 0, 4 ) == $year
               || substr( $quotes{ $symbol, "isodate" }, 0, 4 ) == $lastyear );
    ok(    substr( $quotes{ $symbol, "date" }, 6, 4 ) == $year
               || substr( $quotes{ $symbol, "date" }, 6, 4 ) == $lastyear );
}

ok( $quotes{ "IBM", "currency" } = 'USD' );
ok( $quotes{ "CSCO", "currency" } = 'USD' );
ok( $quotes{ "SOLB.BR", "currency" } = 'EUR' );
ok( $quotes{ "LSE.L", "currency" } = 'GBP' );

ok( !$quotes{ "BOGUS", "success" } );
