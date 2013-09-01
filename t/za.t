#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 17;

# Test za functions.

my $q      = Finance::Quote->new("ZA");
my $year   = (localtime())[5] + 1900;
my $lastyear = $year - 1;

my %quotes = $q->za("AGL","AMS","BOGUS");
ok(%quotes);

# Check that the last and date values are defined.
ok($quotes{"AGL","success"});
ok($quotes{"AGL","last"} > 0);
ok($quotes{"AGL","high"} > 0);
ok($quotes{"AGL","low"} > 0);
ok(length($quotes{"AGL","date"}) > 0);
ok(substr($quotes{"AGL","isodate"},0,4) == $year ||
   substr($quotes{"AGL","isodate"},0,4) == $lastyear);
ok(substr($quotes{"AGL","date"},6,4) == $year ||
   substr($quotes{"AGL","date"},6,4) == $lastyear);
ok($quotes{"AGL","currency"} eq "ZAR");

ok($quotes{"AMS","success"});
ok($quotes{"AMS","last"} > 0);
ok(length($quotes{"AMS","date"}) > 0);
ok(substr($quotes{"AMS","isodate"},0,4) == $year ||
   substr($quotes{"AMS","isodate"},0,4) == $lastyear);
ok(substr($quotes{"AMS","date"},6,4) == $year ||
   substr($quotes{"AMS","date"},6,4) == $lastyear);
ok($quotes{"AMS","currency"} eq "ZAR");

# Check that a bogus fund returns no-success.
ok($quotes{"BOGUS","success"} == 0);
ok($quotes{"BOGUS","errormsg"} eq "Parse error");
