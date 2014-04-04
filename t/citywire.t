#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 8;

my $q      = Finance::Quote->new();
my $year   = (localtime())[5] + 1900;
my $lastyear = $year - 1;

my %quotes = $q->citywire("GB0003865390","GB0003865176","GB0033696674","BOGUS");
ok(%quotes);

# Check the last values are defined.  These are the most
#  used and most reliable indicators of success.
ok($quotes{"GB0003865390","last"} > 0);
ok($quotes{"GB0003865390","success"});

ok($quotes{"GB0003865176","last"} > 0);
ok($quotes{"GB0003865176","success"});

ok($quotes{"GB0033696674","last"} > 0);
ok($quotes{"GB0033696674","success"});

# Check that bogus stocks return failure:

ok(! $quotes{"BOGUS","success"});
