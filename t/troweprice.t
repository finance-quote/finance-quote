#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 5};

use Finance::Quote;

# Test troweprice functions.

my $q      = Finance::Quote->new();

my %quotes = $q->troweprice;
ok(defined(%quotes));

# Check that nav and date are defined as our tests.
ok($quotes{"PRFDX","nav"} > 0);
ok(length($quotes{"PRFDX","nav"}) > 0);
ok($quotes{"PRIDX","nav"} > 0);
ok(length($quotes{"PRIDX","date"}) > 0);
