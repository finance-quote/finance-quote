#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 18};

use Finance::Quote;

# Test Fidelity functions.

my $q      = Finance::Quote->new();
my @funds = qw/FGRIX FNMIX FASGX FCONX/;

my %quotes = $q->fidelity(@funds);
ok(defined(%quotes));

# Check that the name and nav are defined for all of the funds.
foreach my $fund (@funds) {
	ok($quotes{$fund,"nav"} > 0);
	ok(length($quotes{$fund,"name"}));
	ok($quotes{$fund,"success"});
}

# Some funds have yields instead of navs.  Check one of them too.
%quotes = $q->fidelity("FGRXX");
ok(defined(%quotes));
ok(length($quotes{"FGRXX","name"}));
ok($quotes{"FGRXX","yield"} != 0);
ok($quotes{"FGRXX","success"});

# Check that a bogus fund returns no-success.
%quotes = $q->fidelity("BOGUS");
ok(! $quotes{"BOGUS","success"});
