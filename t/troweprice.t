#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;
use Time::Piece;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 42;

# Test troweprice functions.

my $q    = Finance::Quote->new();
my $year = localtime()->year;

my @symbols = qw/
    PRFDX
    PRIDX
    TEUIX
    RPGEX
    GTFBX
/;

ok( my %quotes = $q->troweprice(@symbols, 'BOGUS'), 'Fetched quotes' );

foreach my $symbol (@symbols) {

    ok( length $quotes{$symbol, "name"} > 0,   "$symbol name length > 0");
    ok( $quotes{$symbol, "nav"} > 0,           "$symbol nav > 0");
    ok( $quotes{$symbol, "price"} > 0,         "$symbol price > 0");
    ok( $quotes{$symbol, "symbol"} eq $symbol, "$symbol symbol match");
    ok( length $quotes{$symbol, "date"} > 0,   "$symbol date length > 0");
    
    my $quote_year = substr($quotes{$symbol, "isodate"}, 0, 4 );
    ok ($quote_year == $year || $quote_year - 1 == $year,
        "$symbol isodate year check");
    ok($quotes{$symbol, "method"} eq "troweprice",
        "$symbol method is troweprice");
    ok($quotes{$symbol, "currency"} eq 'USD',
        "$symbol currency as expected");

}

# Check a bogus fund returns no-success
ok(! $quotes{"BOGUS","success"});
