#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 15};

use Finance::Quote;

# Test AEX functions.

my $quoter = Finance::Quote->new();

my %quotes = $quoter->aex("phi","asml","aex");
ok(%quotes);

# Check that some values are defined.
ok($quotes{"phi","success"});
ok($quotes{"phi","last"} > 0);
ok($quotes{"phi","date"});
ok($quotes{"phi","volume"} > 0);
ok($quotes{"asml","success"});
ok($quotes{"asml","time"});
ok($quotes{"asml","volume"} > 0);

# Check that some values are undefined.
ok($quotes{"aex","success"});
ok($quotes{"aex","last"} > 0);
ok( !defined($quotes{"aex","volume"}) );


# Exercise the fetch function 
%quotes = $quoter->fetch("aex","aab");
ok(%quotes);
ok($quotes{"aab","success"});
ok($quotes{"aab","last"} > 0);

# Check that a bogus fund returns no-success.
%quotes = $quoter->aex("BOGUS");
ok( ! $quotes{"BOGUS","success"});
