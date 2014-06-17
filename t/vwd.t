#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 1 + 3 * 6 + 2;

# Test vwd functions.

my $year = (localtime())[5] + 1900;
my $lastyear = $year - 1;
my $q      = Finance::Quote->new("VWD");

my %quotes = $q->vwd("847402","LU0309191491","971675","BOGUS");
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

# Check that the last and date values are defined.
ok($quotes{"LU0309191491","success"});
ok($quotes{"LU0309191491","last"} > 0);
ok(length($quotes{"LU0309191491","date"}) > 0);
ok(substr($quotes{"LU0309191491","isodate"},0,4) == $year ||
   substr($quotes{"LU0309191491","isodate"},0,4) == $lastyear);
ok(substr($quotes{"LU0309191491","date"},6,4) == $year ||
   substr($quotes{"LU0309191491","date"},6,4) == $lastyear);
ok($quotes{"LU0309191491","currency"} eq "EUR");

# Check that the last and date values are defined. stock 971675
ok($quotes{"971675","success"});
ok($quotes{"971675","last"} > 0);
ok(length($quotes{"971675","date"}) > 0);
ok(substr($quotes{"971675","isodate"},0,4) == $year ||
   substr($quotes{"971675","isodate"},0,4) == $lastyear);
ok(substr($quotes{"971675","date"},6,4) == $year ||
   substr($quotes{"971675","date"},6,4) == $lastyear);
ok($quotes{"971675","currency"} eq "DKK","Currency for 971675 (".$quotes{"971675","currency"}.") = DKK");

# Check that a bogus fund returns no-success.
ok($quotes{"BOGUS","success"} == 0);
ok($quotes{"BOGUS","errormsg"} eq "Parse error"); # invalid symbols not detected anymore
