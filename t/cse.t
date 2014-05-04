#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 12;

# Test CSE functions.

my $quoter = Finance::Quote->new();

my %quotes = $quoter->cse("JKH.N0000");
ok(%quotes);

# Check that some values are defined.
ok($quotes{"JKH.N0000","success"},"success");
ok($quotes{"JKH.N0000","last"} > 0,"last > 0");
ok($quotes{"JKH.N0000","volume"} > 0,"volume > 0");
TODO: {
    local $TODO = "No 'open' returned when market closed ?" ;
    ok($quotes{"JKH.N0000","open"},"open is defined");
}
ok($quotes{"JKH.N0000","high"},"high is defined");
ok($quotes{"JKH.N0000","low"},"low is defined");
ok($quotes{"JKH.N0000","close"},"close is defined");

# Exercise the fetch function
%quotes = $quoter->fetch("cse", "JKH.N0000");
ok(%quotes);
ok($quotes{"JKH.N0000","success"});
ok($quotes{"JKH.N0000","last"} > 0);

# Check that a bogus fund returns no-success.
%quotes = $quoter->cse("BOGUS");
ok( ! $quotes{"BOGUS","success"});
