#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 8;

# Test Canadian Fund Library functions.

my $q      = Finance::Quote->new();

my %quotes = $q->fundlibrary("19001","00000");
ok(%quotes);

# Check the last values are defined.  These are the most
#  used and most reliable indicators of success.
ok($quotes{"19001","last"} > 0);
ok($quotes{"19001","success"});
ok($quotes{"19001", "currency"} eq "CAD");
ok(length($quotes{"19001","date"}) > 0);

my $year = (localtime())[5] + 1900;
my $lastyear = $year - 1;
ok(substr($quotes{"19001","isodate"},0,4) == $year ||
   substr($quotes{"19001","isodate"},0,4) == $lastyear);
ok(substr($quotes{"19001","date"},6,4) == $year ||
   substr($quotes{"19001","date"},6,4) == $lastyear);

# Check that bogus stocks return failure:

ok(! $quotes{"00000","success"});
