#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 30};

use Finance::Quote;

# Test Fidelity functions.

my $q      = Finance::Quote->new();
my @funds = ("1#176#170", "1#134", "1#129#122", "1#173", "1#187#196",
	     "1#15#487", "1#1#2");

my %quotes = $q->fetch("indiamutual", @funds);
ok(%quotes);

# Check that the name and nav are defined for all of the funds.
foreach my $fund (@funds) {
	ok($quotes{$fund,"nav"} > 0);
	ok(length($quotes{$fund,"name"}));
	ok($quotes{$fund,"success"});
        ok($quotes{$fund, "currency"} eq "INR");
}

# Check that a bogus fund returns no-success.
%quotes = $q->fetch("indiamutual", "BOGUS");
ok(! $quotes{"BOGUS","success"});
