#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 8};

use Finance::Quote;

# Test TD Waterhouse functions.

my $q      = Finance::Quote->new();

my %quotes = $q->tdwaterhouse("TD U.S. Equity US","TD Canadian Bond Index","BOGUS");
ok(%quotes);

# Check the last values are defined.  These are the most
#  used and most reliable indicators of success.
ok($quotes{"TD U.S. Equity US","last"} > 0);
ok($quotes{"TD U.S. Equity US","success"});
ok($quotes{"TD U.S. Equity US", "currency"} eq "USD");

ok($quotes{"TD Canadian Bond Index","last"} > 0);
ok($quotes{"TD Canadian Bond Index","success"});
ok($quotes{"TD Canadian Bond Index", "currency"} eq "CAD");


# Check that bogus stocks return failure:

ok(! $quotes{"BOGUS","success"});
