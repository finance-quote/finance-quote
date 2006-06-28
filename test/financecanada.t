#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 14};

use Finance::Quote;

# Test Finance Canada functions.

my $q      = Finance::Quote->new();
my @stocks = ("CLG*AGI", "PCA*LDB");
my $year = (localtime())[5] + 1900;

my %quotes = $q->fetch("financecanada", @stocks);
ok(%quotes);

# Check that the name and nav are defined for all of the stocks.
foreach my $stock (@stocks) {
	ok($quotes{$stock,"price"} > 0);
	ok(length($quotes{$stock,"name"}));
	ok($quotes{$stock,"success"});
        ok($quotes{$stock, "currency"} eq "CAD");
	ok(substr($quotes{$stock,"isodate"},0,4) == $year);
	ok(substr($quotes{$stock,"date"},6,4) == $year);
}

# Check that a bogus stock returns no-success.
%quotes = $q->fetch("financecanada", "BOGUS");
ok(! $quotes{"BOGUS","success"});
