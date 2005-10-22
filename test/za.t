#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 11};

use Finance::Quote;

# Test za functions.

my $q      = Finance::Quote->new("ZA");

my %quotes = $q->za("AGL","AMS","BOGUS");
ok(%quotes);

# Check that the last and date values are defined.
ok($quotes{"AGL","success"});
ok($quotes{"AGL","last"} > 0);
ok(length($quotes{"AGL","date"}) > 0);
ok($quotes{"AGL","currency"} eq "ZAR");

ok($quotes{"AMS","success"});
ok($quotes{"AMS","last"} > 0);
ok(length($quotes{"AMS","date"}) > 0);
ok($quotes{"AMS","currency"} eq "ZAR");

# Check that a bogus fund returns no-success.
ok($quotes{"BOGUS","success"} == 0);
ok($quotes{"BOGUS","errormsg"} eq "Parse error");
