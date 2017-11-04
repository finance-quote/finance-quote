#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 13;

# Test MorningstarUS functions.

my $q      = Finance::Quote->new();
my $year = (localtime())[5] + 1900;
my $lastyear = $year - 1;
my @funds = qw/IBM BOGUS VSPMX/;

my %quotes = $q->morningstarus(@funds);
ok(%quotes);

ok($quotes{"IBM","success"});
ok($quotes{"IBM","open"} > 0);
ok($quotes{"IBM","close"} > 0);
ok($quotes{"IBM","high"} > 0);
ok($quotes{"IBM","low"} > 0);
ok(substr($quotes{"IBM","isodate"},0,4) == $year ||
    substr($quotes{"IBM","isodate"},0,4) == $lastyear);
ok(substr($quotes{"IBM","date"},6,4) == $year ||
    substr($quotes{"IBM","date"},6,4) == $lastyear);

ok($quotes{"VSPMX","success"});
ok($quotes{"VSPMX","open"} > 0);
ok($quotes{"VSPMX","close"} > 0);
ok($quotes{"VSPMX","price"} > 0);

ok(! $quotes{"BOGUS","success"});
