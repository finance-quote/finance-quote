#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 3};

use Finance::Quote;

# Test Yahoo functions.

my $q      = Finance::Quote->new();

my %quotes = $q->yahoo("IBM","SGI","XXXYAX");
ok(defined(%quotes));

# Check the last values are defined.  These are the most
#  used and most reliable indicators of success.
ok($quotes{"IBM","last"} > 0);
ok($quotes{"SGI","last"} > 0);
