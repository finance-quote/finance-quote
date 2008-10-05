#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 9;

# Test Cominvest functions.

my $q      = Finance::Quote->new("Cominvest");

my %quotes = $q->fetch("cominvest","DE0008471178","BOGUS");
ok(%quotes);

# Check that the price and date values are defined.
ok($quotes{"DE0008471178","success"});
ok($quotes{"DE0008471178","price"} > 0);
ok(length($quotes{"DE0008471178","date"}) > 0);
ok($quotes{"DE0008471178","currency"});

my $year = (localtime())[5] + 1900;
my $lastyear = $year - 1;
ok((substr($quotes{"DE0008471178","isodate"},0,4) == $year) ||
   (substr($quotes{"DE0008471178","isodate"},0,4) == $lastyear));
ok((substr($quotes{"DE0008471178","date"},6,4) == $year) ||
   (substr($quotes{"DE0008471178","date"},6,4) == $lastyear));

# Check that a bogus fund returns no-success and has a error message
ok(! $quotes{"BOGUS","success"});
ok($quotes{"BOGUS","errormsg"});

