#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 8};

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
ok(length($quotes{"19001","date"}) > 0);

my $year = (localtime())[5] + 1900;
ok(substr($quotes{"19001","isodate"},0,4) == $year);
ok(substr($quotes{"19001","date"},6,4) == $year);

# Check that bogus stocks return failure:

ok(! $quotes{"00000","success"});
