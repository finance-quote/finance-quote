#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 12};

use Finance::Quote;

# Test TD Waterhouse functions.

my $q      = Finance::Quote->new();
my $year   = (localtime())[5] + 1900;

my %quotes = $q->tdwaterhouse("TD U.S. Equity US","TD Canadian Bond Index","BOGUS");
ok(%quotes);

# Check the last values are defined.  These are the most
#  used and most reliable indicators of success.
ok($quotes{"TD U.S. Equity US","last"} > 0);
ok($quotes{"TD U.S. Equity US","success"});
ok($quotes{"TD U.S. Equity US", "currency"} eq "USD");
ok(substr($quotes{"TD U.S. Equity US","isodate"},0,4) == $year);
ok(substr($quotes{"TD U.S. Equity US","date"},6,4) == $year);

ok($quotes{"TD Canadian Bond Index","last"} > 0);
ok($quotes{"TD Canadian Bond Index","success"});
ok($quotes{"TD Canadian Bond Index", "currency"} eq "CAD");
ok(substr($quotes{"TD Canadian Bond Index","isodate"},0,4) == $year);
ok(substr($quotes{"TD Canadian Bond Index","date"},6,4) == $year);

# Check that bogus stocks return failure:

ok(! $quotes{"BOGUS","success"});
