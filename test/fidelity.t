#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 25};

use Finance::Quote;

# Test Fidelity functions.

my $q      = Finance::Quote->new();
my @funds = qw/FGRIX FNMIX FASGX/;
my $year = (localtime())[5] + 1900;

my %quotes = $q->fidelity_direct(@funds);
ok(%quotes);

# Check that the name and nav are defined for all of the funds.
foreach my $fund (@funds) {
	ok($quotes{$fund,"nav"} > 0);
	ok(length($quotes{$fund,"name"}));
	ok($quotes{$fund,"success"});
        ok($quotes{$fund, "currency"} eq "USD");
	ok(substr($quotes{$fund,"isodate"},0,4) == $year);
	ok(substr($quotes{$fund,"date"},6,4) == $year);
}

# Some funds have yields instead of navs.  Check one of them too.
%quotes = $q->fidelity_direct("FGRXX");
ok(%quotes);
ok(length($quotes{"FGRXX","name"}));
ok($quotes{"FGRXX","yield"} != 0);
ok($quotes{"FGRXX","success"});
ok($quotes{"FGRXX", "currency"} eq "USD");

# Check that a bogus fund returns no-success.
%quotes = $q->fidelity_direct("BOGUS");
ok(! $quotes{"BOGUS","success"});
