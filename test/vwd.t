#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 9};

use Finance::Quote;

# Test vwd functions.

my $year = (localtime())[5] + 1900;
my $lastyear = $year - 1;
my $q      = Finance::Quote->new("VWD");

my %quotes = $q->vwd("847402","BOGUS");
ok(%quotes);

# Check that the last and date values are defined.
ok($quotes{"847402","success"});
ok($quotes{"847402","last"} > 0);
ok(length($quotes{"847402","date"}) > 0);
ok(substr($quotes{"847402","isodate"},0,4) == $year ||
   substr($quotes{"847402","isodate"},0,4) == $lastyear);
ok(substr($quotes{"847402","date"},6,4) == $year ||
   substr($quotes{"847402","date"},6,4) == $lastyear);
ok($quotes{"847402","currency"} eq "EUR");

# Check that a bogus fund returns no-success.
ok($quotes{"BOGUS","success"} == 0);
ok($quotes{"BOGUS","errormsg"} eq "Invalid symbol: BOGUS");
