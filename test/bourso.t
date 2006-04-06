#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 14};

use Finance::Quote;

# Test Fidelity functions.

my $q      = Finance::Quote->new();
my @stocks = ("AF", "ML");
my $year = (localtime())[5] + 1900;

my %quotes = $q->fetch("bourso", @stocks);
ok(%quotes);

# Check that the name and nav are defined for all of the stocks.
foreach my $stock (@stocks) {
	ok($quotes{$stock,"nav"} > 0);
	ok(length($quotes{$stock,"name"}));
	ok($quotes{$stock,"success"});
        ok($quotes{$stock, "currency"} eq "EUR");
	ok(substr($quotes{$stock,"isodate"},0,4) == $year);
	ok(substr($quotes{$stock,"date"},6,4) == $year);
}

# Check that a bogus stock returns no-success.
%quotes = $q->fetch("bourso", "BOGUS");
ok(! $quotes{"BOGUS","success"});
