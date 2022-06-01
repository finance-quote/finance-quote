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

my %quotes = $q->morningstarch("CH0012056260","CH0014933193","CH0002788567","BOGUS");
ok(%quotes);

# Check the last values are defined.  These are the most
#  used and most reliable indicators of success.
ok($quotes{"CH0012056260","last"} > 0);
ok($quotes{"CH0012056260","success"});

ok($quotes{"CH0014933193","last"} > 0);
ok($quotes{"CH0014933193","success"});

ok($quotes{"CH0002788567","last"} > 0);
ok($quotes{"CH0002788567","success"});

# Check that bogus stocks return failure:

ok(! $quotes{"BOGUS","success"});
