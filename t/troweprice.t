#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 13;

# Test troweprice functions.

my $q      = Finance::Quote->new();
my $year   = (localtime())[5] + 1900;
my $lastyear = $year - 1;

my %quotes = $q->troweprice;
ok(%quotes);

# Check that nav and date are defined as our tests.
ok($quotes{"PRFDX","nav"} > 0);
ok($quotes{"PRFDX","success"});
ok($quotes{"PRFDX","currency"} eq "USD");
ok(length($quotes{"PRFDX","date"}) > 0);
ok(substr($quotes{"PRFDX","isodate"},0,4) == $year ||
   substr($quotes{"PRFDX","isodate"},0,4) == $lastyear);
ok(substr($quotes{"PRFDX","date"},6,4) == $year ||
   substr($quotes{"PRFDX","date"},6,4) == $lastyear);


ok($quotes{"PRIDX","success"});
ok($quotes{"PRIDX","nav"} > 0);
ok(length($quotes{"PRIDX","date"}) > 0);
ok(substr($quotes{"PRIDX","isodate"},0,4) == $year ||
   substr($quotes{"PRIDX","isodate"},0,4) == $lastyear);
ok(substr($quotes{"PRIDX","date"},6,4) == $year ||
   substr($quotes{"PRIDX","date"},6,4) == $lastyear);

# Check a bogus fund returns no-success

%quotes = $q->troweprice("BOGUS");
ok(! $quotes{"BOGUS","success"});
