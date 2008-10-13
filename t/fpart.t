#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 8};

use Finance::Quote;

# Test finanzpartner functions.

my $year = (localtime())[5] + 1900;
my $lastyear = $year - 1;
my $q      = Finance::Quote->new("Finanzpartner");

my %quotes = $q->finanzpartner("LU0055732977","BOGUS");
ok(%quotes);

# Check that the last and date values are defined.
ok($quotes{"LU0055732977","success"});
ok($quotes{"LU0055732977","last"} > 0);
ok(length($quotes{"LU0055732977","date"}) > 0);
ok(substr($quotes{"LU0055732977","isodate"},0,4) == $year ||
   substr($quotes{"LU0055732977","isodate"},0,4) == $lastyear);
ok(substr($quotes{"LU0055732977","date"},6,4) == $year ||
   substr($quotes{"LU0055732977","date"},6,4) == $lastyear);
ok($quotes{"LU0055732977","currency"} eq "USD");

# Check that a bogus fund returns non-success.
ok($quotes{"BOGUS","success"} == 0);

