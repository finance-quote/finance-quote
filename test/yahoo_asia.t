#!/usr/bin/perl -w
use strict;
use Test;
use Data::Dumper;
BEGIN {plan tests => 7};

use Finance::Quote;

# Test Yahoo_europe functions.

my $q      = Finance::Quote->new();

my %quotes = $q->asia("C76.SI","BOGUS.SI");
ok(%quotes);

# Check the nav values are defined.  These are the most
#  used and most reliable indicators of success.
ok($quotes{"C76.SI","last"} > 0);
ok(length($quotes{"C76.SI","name"}) > 0);
ok($quotes{"C76.SI","success"});
ok($quotes{"C76.SI", "currency"} eq "SGD");

# Make sure we don't have spurious % signs.

ok($quotes{"C76.SI","p_change"} !~ /%/);

# Check that a bogus stock returns no-success.
ok(! $quotes{"BOGUS.SI","success"});
