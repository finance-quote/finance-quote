#!/usr/bin/perl -w
use strict;
use Test;
use Data::Dumper;
BEGIN {plan tests => 7};

use Finance::Quote;

# Test Yahoo_europe functions.

my $q      = Finance::Quote->new();

my %quotes = $q->yahoo_brasil("VULC3","BOGUS");
ok(%quotes);

# Check the nav values are defined.  These are the most
#  used and most reliable indicators of success.
ok($quotes{"VULC3","last"} > 0);
ok(length($quotes{"VULC3","name"}) > 0);
ok($quotes{"VULC3","success"});
ok($quotes{"VULC3", "currency"} eq "BRL");

# Make sure we don't have spurious % signs.

ok($quotes{"VULC3","p_change"} !~ /%/);

# Check that a bogus stock returns no-success.
ok(! $quotes{"BOGUS","success"});
