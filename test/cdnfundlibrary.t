#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 5};

use Finance::Quote;

# Test Canadian Fund Library functions.

my $q      = Finance::Quote->new();

my %quotes = $q->fundlibrary("19001","00000");
ok(%quotes);

# Check the last values are defined.  These are the most
#  used and most reliable indicators of success.
ok($quotes{"19001","last"} > 0);
ok($quotes{"19001","success"});
ok($quotes{"19001", "currency"} eq "CAD");

# Check that bogus stocks return failure:

ok(! $quotes{"00000","success"});
