#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if ( not $ENV{"ONLINE_TEST"} ) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

if ( not $ENV{"FQ_GENERIC_EXECUTOR"} ) {
    plan skip_all =>
        'Set $ENV{FQ_GENERIC_EXECUTOR} to run this test. This shouls be set to interpreter binary, like python.';
}

if ( not $ENV{"FQ_GENERIC_FETCHER"} ) {
    plan skip_all =>
        'Set $ENV{FQ_GENERIC_FETCHER} to run this test. This should be a script that is passed to the interpreter.';
}

my $q        = Finance::Quote->new('GenericExecutor', 'parameters' => {'EXECUTOR' => $ENV{"FQ_GENERIC_EXECUTOR"}, 'FETCHER' => $ENV{"FQ_GENERIC_FETCHER"}} );
my $year     = ( localtime() )[5] + 1900;
my $lastyear = $year - 1;

my @symbols = qw/
    SUZLON.BO
    RECLTD.NS
    AMZN
    SOLB.BR
    ^DJI
    BEL20.BR
    INGDIRECTFNE.BC
    AENA.MC
    CFR.JO
/;

plan tests => 1 + 11*(1+$#symbols) + 10;

my %quotes = $q->run_executor( @symbols, "BOGUS" );
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

is( $quotes{ "BP.L", "currency" }, 'GBP' );
is( $quotes{ "CSCO", "currency" }, 'USD' );
is( $quotes{ "DIVO11.SA", "currency" }, 'BRL' );
is( $quotes{ "ERCB.DE", "currency" }, 'EUR' );
is( $quotes{ "IBM", "currency" }, 'USD' );
is( $quotes{ "MRT-UN.TRT", "currency" }, 'CAD' );
is( $quotes{ "SAP.DE", "currency" }, 'EUR' );
is( $quotes{ "SOLB.BR", "currency" }, 'EUR' );
is( $quotes{ "TD.TO", "currency" }, 'CAD' );

ok( !$quotes{ "BOGUS", "success" } );
