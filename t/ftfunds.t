#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 12;

my $q      = Finance::Quote->new();
my $year   = (localtime())[5] + 1900;
my $lastyear = $year - 1;

my %quotes = $q->ftfunds("GB0031834814","GB0030881337","GB0003865176","GB00B7W6PR65","BOGUS");
ok(%quotes);

# Check the last values are defined.  These are the most
#  used and most reliable indicators of success.
ok($quotes{"GB0031834814","last"} > 0);
ok($quotes{"GB0031834814","success"});

ok($quotes{"GB00B7W6PR65","last"} > 0);
ok($quotes{"GB00B7W6PR65","success"});
ok($quotes{"GB00B7W6PR65","currency"} eq "GBP", "Currency (GBP) for GB00B7W6PR65 is ".$quotes{"GB00B7W6PR65","currency"});
ok($quotes{"GB00B7W6PR65","price"}<100,"Price for GB00B7W6PR65 < 100 : ".$quotes{"GB00B7W6PR65","price"});

ok($quotes{"GB0030881337","last"} > 0);
ok($quotes{"GB0030881337","success"});

ok($quotes{"GB0003865176","last"} > 0);
ok($quotes{"GB0003865176","success"});

# Check that bogus stocks return failure:

ok(! $quotes{"BOGUS","success"});
