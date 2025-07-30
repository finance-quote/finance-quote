#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 8;

my $q      = Finance::Quote->new('SwissFundData');
my $year   = (localtime())[5] + 1900;
my $lastyear = $year - 1;

my %quotes = $q->swissfunddata("CH0012056260","CH0014933193","CH0316793139","BOGUS");
ok(%quotes);

# Check the nav values are defined.  These are the most
#  used and most reliable indicators of success.
ok($quotes{"CH0012056260","nav"} > 0);
ok($quotes{"CH0012056260","success"});

ok($quotes{"CH0014933193","nav"} > 0);
ok($quotes{"CH0014933193","success"});

ok($quotes{"CH0316793139","nav"} > 0);
ok($quotes{"CH0316793139","success"});

# Check that bogus stocks return failure:

ok(! $quotes{"BOGUS","success"});
