#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 7};

use Finance::Quote;

# Test deka functions.

my $q      = Finance::Quote->new("Deka");

my %quotes = $q->deka("DE0008474511","BOGUS");
ok(%quotes);

# Check that the last and date values are defined.
ok($quotes{"DE0008474511","success"});
ok($quotes{"DE0008474511","last"} > 0);
ok(length($quotes{"DE0008474511","date"}) > 0);
ok($quotes{"DE0008474511","currency"} eq "EUR");

# Check that a bogus fund returns no-success.
ok($quotes{"BOGUS","success"} == 0);
ok($quotes{"BOGUS","errormsg"} eq "Couldn't parse deka website");
