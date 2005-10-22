#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 16};

use Finance::Quote;

# Test TSP functions.

my $quoter = Finance::Quote->new();

my %quotes = $quoter->tsp("c","s","TSPgfund","BOGUS","l2040fund");
ok(%quotes);

# Check that some values are defined.
ok($quotes{"c","success"});
ok($quotes{"c","nav"} > 0);
ok($quotes{"l2040fund","date"});
ok($quotes{"s","currency"});
ok($quotes{"s","name"});
ok($quotes{"TSPgfund","success"});
ok($quotes{"TSPgfund","nav"} > 0);
ok($quotes{"TSPgfund","date"});

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
ok($quotes{"tsplincomefund","nav"} > 0);

