#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 9;

# Test Morningstar functions.

my $q      = Finance::Quote->new();
my $year   = (localtime())[5] + 1900;
my $lastyear = $year - 1;

my @stocks = ("F0GBR069L2","BOGUS");

my %quotes = $q->fetch("morningstar",@stocks);
ok(%quotes);

# Check the nav values are defined.  These are the most
#  used and most reliable indicators of success.
ok($quotes{"F0GBR069L2","price"} > 0);
ok(length($quotes{"F0GBR069L2","name"}) > 0);
ok($quotes{"F0GBR069L2","success"});
ok($quotes{"F0GBR069L2", "currency"} eq "USD");
ok(substr($quotes{"F0GBR069L2","isodate"},0,4) == $year ||
   substr($quotes{"F0GBR069L2","isodate"},0,4) == $lastyear);
ok(substr($quotes{"F0GBR069L2","date"},6,4) == $year ||
   substr($quotes{"F0GBR069L2","date"},6,4) == $lastyear);

# Make sure we don't have spurious % signs.

ok($quotes{"F0GBR069L2","p_change"} !~ /%/);

# Check that a bogus stock returns no-success.
ok(! $quotes{"BOGUS","success"});

