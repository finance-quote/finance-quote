#!/usr/bin/perl -w
use strict;
use Test;
use Data::Dumper;
BEGIN {plan tests => 6};

use Finance::Quote;

# Test Yahoo_europe functions.

my $q      = Finance::Quote->new();

my %quotes = $q->yahoo_europe("12150.PA","BOGUS");
ok(defined(%quotes));

# Check the nav values are defined.  These are the most
#  used and most reliable indicators of success.
ok($quotes{"12150.PA","last"} > 0);
ok(length($quotes{"12150.PA","name"}) > 0);
ok($quotes{"12150.PA","success"});
ok($quotes{"12150.PA", "currency"} eq "EUR");

# Check that a bogus stock returns no-success.
ok(! $quotes{"BOGUS","success"});
