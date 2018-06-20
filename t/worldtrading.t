#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if ( not $ENV{"ONLINE_TEST"} ) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

if ( not $ENV{"WORLDTRADING_API_KEY"} ) {
    plan skip_all =>
        'Set $ENV{WORLDTRADING_API_KEY} to run this test; get one at https://www.worldtradingdata.com';
}

my $q        = Finance::Quote->new();
my $year     = ( localtime() )[5] + 1900;
my $lastyear = $year - 1;

my @symbols =  qw/ IBM CSCO SOLB.BR SAP.DE TD.TO LSE.L VFIAX T FILA.MI SANB11.SA/;

plan tests => 10*(1+$#symbols)+10;

my %quotes = $q->worldtrading( @symbols, "BOGUS" );
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
    ok(    substr( $quotes{ $symbol, "isodate" }, 0, 4 ) == $year
               || substr( $quotes{ $symbol, "isodate" }, 0, 4 ) == $lastyear );
    ok(    substr( $quotes{ $symbol, "date" }, 6, 4 ) == $year
               || substr( $quotes{ $symbol, "date" }, 6, 4 ) == $lastyear );
}

is( $quotes{ "IBM", "currency" }, 'USD' );
is( $quotes{ "CSCO", "currency" }, 'USD' );
is( $quotes{ "SOLB.BR", "currency" }, 'EUR' );
is( $quotes{ "SAP.DE", "currency" }, 'EUR' );
is( $quotes{ "TD.TO", "currency" }, 'CAD' );
is( $quotes{ "LSE.L", "currency" }, 'GBX' );
is( $quotes{ "FILA.MI", "currency" }, 'EUR' );
is( $quotes{ "SANB11.SA", "currency" }, 'BRL' );

ok( !$quotes{ "BOGUS", "success" } );
