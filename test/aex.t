#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 24};

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

# Test options fetching
%quotes = $quoter->fetch("aex_options", "aex c oct 2007 300.00", "phi");
ok(%quotes);

# the following test will fail after Oct 2007 :-(
ok($quotes{"aex c oct 2007 300.00","success"});
ok($quotes{"aex c oct 2007 300.00","close"} > 0);
ok($quotes{"aex c oct 2007 300.00","bid"});
ok($quotes{"aex c oct 2007 300.00","ask"});

ok($quotes{"phi","success"});
ok($quotes{"phi","options"});
ok($quotes{ $quotes{"phi","options"}->[0],"close"});
ok($quotes{ $quotes{"phi","options"}->[0],"date"});

# Check that a bogus fund returns no-success.
%quotes = $quoter->aex("BOGUS");
ok( ! $quotes{"BOGUS","success"});
