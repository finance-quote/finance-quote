#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 26;

# Test Finance Canada functions.

my $q      = Finance::Quote->new();
my @stocks = ("NT","XIU","UUU", "PCA");
my $year = (localtime())[5] + 1900;
my $lastyear = $year - 1;

my %quotes = $q->fetch("financecanada", @stocks);
ok(%quotes);

# Check that the name and nav are defined for all of the stocks.
foreach my $stock (@stocks) {
	ok($quotes{$stock,"price"} > 0);
	ok(length($quotes{$stock,"name"}));
	ok($quotes{$stock,"success"});
        ok($quotes{$stock, "currency"} eq "CAD");
	ok(substr($quotes{$stock,"isodate"},0,4) == $year ||
	   substr($quotes{$stock,"isodate"},0,4) == $lastyear);
	ok(substr($quotes{$stock,"date"},6,4) == $year ||
	   substr($quotes{$stock,"date"},6,4) == $lastyear);
}

# Check that a bogus stock returns no-success.
%quotes = $q->fetch("financecanada", "BOGUS");
ok(! $quotes{"BOGUS","success"});
