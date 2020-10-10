#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 16;

# Test Fundata functions.

my $q      = Finance::Quote->new();
my @stocks = ("301871", "234263");
my $year = (localtime())[5] + 1900;
my $lastyear = $year - 1;

my %quotes = $q->fetch("fundata", @stocks);
ok(%quotes);

# Check that the symbol and nav are defined for all of the stocks.
foreach my $stock (@stocks) {
	ok($quotes{$stock,"nav"} > 0);
    ok(length($quotes{$stock,"name"}));
	ok(length($quotes{$stock,"symbol"}));
	ok($quotes{$stock,"success"});
	ok(substr($quotes{$stock,"isodate"},0,4) == $year ||
	   substr($quotes{$stock,"isodate"},0,4) == $lastyear);
	ok(substr($quotes{$stock,"date"},6,4) == $year ||
	   substr($quotes{$stock,"date"},6,4) == $lastyear);
}

ok($quotes{"301871", "currency"} eq "CAD");
ok($quotes{"234263", "currency"} eq "CAD");

# Check that a bogus stock returns no-success.
%quotes = $q->fetch("fundata", "BOGUS");
ok(! $quotes{"BOGUS","success"}, "BOGUS failed");
