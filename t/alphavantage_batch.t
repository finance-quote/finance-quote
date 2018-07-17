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

my @symbols =  qw/ IBM CSCO T TWTR AAPL ORCL FB CMCSA INTC NFLX TSLA NOK BAC GOOG F AXP/;

plan tests => 6*(1+$#symbols)+4;

my %quotes = $q->alphavantage_batch( @symbols, "BOGUS" );
ok(%quotes);

foreach my $symbol (@symbols) {
    ok( $quotes{ $symbol, "success" }, "$symbol success" );
    ok( $quotes{ $symbol, "symbol" } eq $symbol , "$symbol defined" );
    ok( $quotes{ $symbol, "last" } > 0, "$symbol returned last" );
    ok( $quotes{ $symbol, "volume" } >= 0, "$symbol returned volume" );
    ok(    substr( $quotes{ $symbol, "isodate" }, 0, 4 ) == $year
               || substr( $quotes{ $symbol, "isodate" }, 0, 4 ) == $lastyear );
    ok(    substr( $quotes{ $symbol, "date" }, 6, 4 ) == $year
               || substr( $quotes{ $symbol, "date" }, 6, 4 ) == $lastyear );
}

is( $quotes{ "IBM", "currency" }, 'USD' );
is( $quotes{ "CSCO", "currency" }, 'USD' );

ok( !$quotes{ "BOGUS", "success" } );
