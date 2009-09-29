#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 13;

# Test AEX functions.

my $quoter = Finance::Quote->new();

my %quotes = $quoter->aex("AH");
ok(%quotes);

# Check that some values are defined.
ok($quotes{"AH","success"});
ok($quotes{"AH","last"} > 0);
ok($quotes{"AH","date"});
ok($quotes{"AH","volume"} > 0);

my $year = (localtime())[5] + 1900;
my $lastyear = $year - 1;
ok(substr($quotes{"AH","isodate"},0,4) == $year ||
   substr($quotes{"AH","isodate"},0,4) == $lastyear);
ok(substr($quotes{"AH","date"},6,4) == $year ||
   substr($quotes{"AH","date"},6,4) == $lastyear);

# Exercise the fetch function 
%quotes = $quoter->fetch("aex","AMG");
ok(%quotes);
ok($quotes{"AMG","success"});
ok($quotes{"AMG","last"} > 0);

# Check fetching on based on ISIN 
%quotes = $quoter->aex("NL0000009165");  # NL0000009165 ==  Heineken == HEIA
ok(%quotes);
ok($quotes{"NL0000009165","success"});

# Check that a bogus fund returns no-success.
%quotes = $quoter->aex("BOGUS");
ok( ! $quotes{"BOGUS","success"});
