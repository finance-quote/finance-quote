#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

# Test MumbaiStock functions.

my $q = Finance::Quote->new();
my @symbols = ("532540", "500008", "500400", "500387", "500390", "500469");
my $year = (localtime())[5] + 1900;
my $lastyear = $year - 1;

# Tests: fetch, fetch BOGUS, and 6 per stock
plan tests => 6*@symbols + 2;

my %quotes = $q->fetch("mumbaistock", @symbols);
ok(%quotes);

# Check that the name and nav are defined for all of the funds.
foreach my $symbol (@symbols) {
	ok($quotes{$symbol,"nav"} > 0);
	ok(length($quotes{$symbol,"name"}));
	ok($quotes{$symbol,"success"});
        ok($quotes{$symbol, "currency"} eq "INR");
	ok(substr($quotes{$symbol,"isodate"},0,4) == $year ||
	   substr($quotes{$symbol,"isodate"},0,4) == $lastyear);
	ok(substr($quotes{$symbol,"date"},6,4) == $year ||
	   substr($quotes{$symbol,"date"},6,4) == $lastyear);
}

# Check that a bogus fund returns no-success.
%quotes = $q->fetch("mumbaistock", "BOGUS");
ok(! $quotes{"BOGUS","success"});
