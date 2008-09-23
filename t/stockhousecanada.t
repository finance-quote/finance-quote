#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 20};

use Finance::Quote;

# Test Stock House Canada functions.

my $q      = Finance::Quote->new();
my @stocks = ("CIB497", "TDB227", "FID342");
my $year = (localtime())[5] + 1900;
my $lastyear = $year - 1;

my %quotes = $q->fetch("stockhousecanada_fund", @stocks);
ok(%quotes);

# Check that the name and nav are defined for all of the stocks.
foreach my $stock (@stocks) {
	ok($quotes{$stock,"price"} > 0);
	ok(length($quotes{$stock,"name"}));
	ok($quotes{$stock,"success"});
	ok(substr($quotes{$stock,"isodate"},0,4) == $year ||
	   substr($quotes{$stock,"isodate"},0,4) == $lastyear);
	ok(substr($quotes{$stock,"date"},6,4) == $year ||
	   substr($quotes{$stock,"date"},6,4) == $lastyear);
}

ok($quotes{"CIB497", "currency"} eq "CAD");
ok($quotes{"TDB227", "currency"} eq "USD");
ok($quotes{"FID342", "currency"} eq "USD");

# Check that a bogus stock returns no-success.
%quotes = $q->fetch("stockhousecanada_fund", "BOGUS");
ok(! $quotes{"BOGUS","success"});
