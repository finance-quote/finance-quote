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

my %quotes = $q->fundlibrary("NBC887","TDB3533","00000");
ok(%quotes);

# Check the last values are defined.  These are the most
#  used and most reliable indicators of success.

my $year = (localtime())[5] + 1900;
my $lastyear = $year - 1;

ok($quotes{"NBC887","last"} > 0);
ok($quotes{"NBC887","success"});
ok($quotes{"NBC887", "currency"} eq "CAD");
ok(length($quotes{"NBC887","date"}) > 0);
ok(substr($quotes{"NBC887","isodate"},0,4) == $year ||
   substr($quotes{"NBC887","isodate"},0,4) == $lastyear);
ok(substr($quotes{"NBC887","date"},6,4) == $year ||
   substr($quotes{"NBC887","date"},6,4) == $lastyear);

ok($quotes{"TDB3533","last"} > 0);
ok($quotes{"TDB3533","success"});
ok($quotes{"TDB3533", "currency"} eq "CAD");
ok(length($quotes{"TDB3533","date"}) > 0);
ok(substr($quotes{"TDB3533","isodate"},0,4) == $year ||
   substr($quotes{"TDB3533","isodate"},0,4) == $lastyear);
ok(substr($quotes{"TDB3533","date"},6,4) == $year ||
   substr($quotes{"TDB3533","date"},6,4) == $lastyear);

# Check that bogus stocks return failure:

ok(! $quotes{"00000","success"});
