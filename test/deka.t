#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 11};

use Finance::Quote;

# Test deka functions.

my $q      = Finance::Quote->new("Deka");

my $year = (localtime())[5] + 1900;
my $lastyear = $year - 1;
my %quotes = $q->deka("DE0008474511","LU0051755006","BOGUS");
ok(%quotes);

# Check that the last and date values are defined.
ok($quotes{"DE0008474511","success"});
ok($quotes{"DE0008474511","last"} > 0);
ok(substr($quotes{"DE0008474511","date"},6,4) == $year ||
   substr($quotes{"DE0008474511","date"},6,4) == $lastyear);
ok($quotes{"DE0008474511","currency"} eq "EUR");

# Check that the last and date values are defined.
ok($quotes{"LU0051755006","success"});
ok($quotes{"LU0051755006","last"} > 0);
ok(substr($quotes{"LU0051755006","date"},6,4) == $year ||
   substr($quotes{"LU0051755006","date"},6,4) == $lastyear);
ok($quotes{"LU0051755006","currency"} eq "USD");

# Check that a bogus fund returns no-success.
ok($quotes{"BOGUS","success"} == 0);
ok($quotes{"BOGUS","errormsg"} eq "Couldn't parse deka website");
