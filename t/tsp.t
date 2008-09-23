#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 22;

# Test TSP functions.

my $year = (localtime())[5] + 1900;
my $lastyear = $year - 1;
my $quoter = Finance::Quote->new();

my %quotes = $quoter->tsp("c","s","TSPgfund","BOGUS","l2040fund");
ok(%quotes);

# Check that some values are defined.
ok($quotes{"c","success"});
ok($quotes{"c","nav"} > 0);
ok($quotes{"l2040fund","date"});
ok(substr($quotes{"l2040fund","isodate"},0,4) == $year ||
   substr($quotes{"l2040fund","isodate"},0,4) == $lastyear);
ok(substr($quotes{"l2040fund","date"},6,4) == $year ||
   substr($quotes{"l2040fund","date"},6,4) == $lastyear);
ok($quotes{"s","currency"});
ok($quotes{"s","name"});
ok($quotes{"TSPgfund","success"});
ok($quotes{"TSPgfund","nav"} > 0);
ok($quotes{"TSPgfund","date"});
ok(substr($quotes{"TSPgfund","isodate"},0,4) == $year ||
   substr($quotes{"TSPgfund","isodate"},0,4) == $lastyear);
ok(substr($quotes{"TSPgfund","date"},6,4) == $year ||
   substr($quotes{"TSPgfund","date"},6,4) == $lastyear);

# Check that some values are undefined.
ok( !defined($quotes{"c","exchange"}) );

# Check that a bogus fund returns no-success.
ok( ! $quotes{"BOGUS","success"});

# Exercise the fetch function 
%quotes = $quoter->fetch("tsp","g","f","i","tsplincomefund");
ok(%quotes);
ok($quotes{"g","success"});
ok($quotes{"f","nav"} > 0);
ok($quotes{"i","date"});
ok(substr($quotes{"i","isodate"},0,4) == $year ||
   substr($quotes{"i","isodate"},0,4) == $lastyear);
ok(substr($quotes{"i","date"},6,4) == $year ||
   substr($quotes{"i","date"},6,4) == $lastyear);
ok($quotes{"tsplincomefund","nav"} > 0);

