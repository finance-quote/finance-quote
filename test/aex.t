#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 9};

use Finance::Quote;

# Test AEX functions.

my $quoter = Finance::Quote->new();

my %quotes = $quoter->aex("AAB 93-08 7.5");
ok(%quotes);

# Check that some values are defined.
ok($quotes{"AAB 93-08 7.5","success"});
ok($quotes{"AAB 93-08 7.5","last"} > 0);
ok($quotes{"AAB 93-08 7.5","date"});
ok($quotes{"AAB 93-08 7.5","volume"} > 0);

# Exercise the fetch function 
%quotes = $quoter->fetch("aex","AAB C Jun 05 20.00");
ok(%quotes);
ok($quotes{"AAB C Jun 05 20.00","success"});
ok($quotes{"AAB C Jun 05 20.00","last"} > 0);


# Check that a bogus fund returns no-success.
%quotes = $quoter->aex("BOGUS");
ok( ! $quotes{"BOGUS","success"});
