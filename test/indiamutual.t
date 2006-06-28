#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 44};

use Finance::Quote;

# Test Fidelity functions.

my $q      = Finance::Quote->new();
my @funds = ("102620", "103134", "101599", "103206", "100151",
	     "102849", "101560");
my $year = (localtime())[5] + 1900;

my %quotes = $q->fetch("indiamutual", @funds);
ok(%quotes);

# Check that the name and nav are defined for all of the funds.
foreach my $fund (@funds) {
	ok($quotes{$fund,"nav"} > 0);
	ok(length($quotes{$fund,"name"}));
	ok($quotes{$fund,"success"});
        ok($quotes{$fund, "currency"} eq "INR");
	ok(substr($quotes{$fund,"isodate"},0,4) == $year);
	ok(substr($quotes{$fund,"date"},6,4) == $year);
}

# Check that a bogus fund returns no-success.
%quotes = $q->fetch("indiamutual", "BOGUS");
ok(! $quotes{"BOGUS","success"});
