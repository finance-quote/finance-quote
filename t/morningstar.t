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

my @stocks = ("0P00000RSZ","BOGUS");

my %quotes = $q->fetch("morningstar",@stocks);
ok(%quotes);

# Check the nav values are defined. These are the most
# used and most reliable indicators of success.
ok($quotes{"0P00000RSZ","nav"} > 0);
ok(length($quotes{"0P00000RSZ","name"}) > 0);
ok($quotes{"0P00000RSZ","success"});
ok($quotes{"0P00000RSZ", "currency"} eq "USD");
ok(substr($quotes{"0P00000RSZ","isodate"},0,4) == $year ||
   substr($quotes{"0P00000RSZ","isodate"},0,4) == $lastyear);
ok(substr($quotes{"0P00000RSZ","date"},6,4) == $year ||
   substr($quotes{"0P00000RSZ","date"},6,4) == $lastyear);

# Make sure we don't have spurious % signs.

ok($quotes{"0P00000RSZ","p_change"} !~ /%/);

# Check that a bogus stock returns no-success.
ok(! $quotes{"BOGUS","success"});

