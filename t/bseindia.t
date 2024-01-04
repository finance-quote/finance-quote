#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

# Test BSEIndia functions.

my $q = Finance::Quote->new();
my @stocks = ("532540", "INE009A01021", "INE062A01020");
my $year = (localtime())[5] + 1900;
my $lastyear = $year - 1;

# Tests: fetch, fetch BOGUS, and 5 per stock
plan tests => 2 + 5*@stocks;

my %quotes = $q->fetch("bseindia", @stocks);
ok(%quotes);

# Check that the name and last are defined for all of the stocks.
foreach my $stock (@stocks) {
    ok($quotes{$stock, "last"} > 0);
    ok($quotes{$stock, "success"});
    ok($quotes{$stock, "currency"} eq "INR");
    ok(substr($quotes{$stock,"isodate"},0,4) == $year ||
       substr($quotes{$stock,"isodate"},0,4) == $lastyear);
    ok(substr($quotes{$stock,"date"},6,4) == $year ||
       substr($quotes{$stock,"date"},6,4) == $lastyear);
}

# Check that a bogus fund returns no-success.
%quotes = $q->fetch("bseindia", "BOGUS");
ok(! $quotes{"BOGUS","success"});
