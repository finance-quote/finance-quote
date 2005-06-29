#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 11};

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

my $year = (localtime())[5] + 1900;
ok(substr($quotes{"AAB 93-08 7.5","isodate"},0,4) == $year);
ok(substr($quotes{"AAB 93-08 7.5","date"},6,4) == $year);

# Exercise the fetch function 
%quotes = $quoter->fetch("aex","AAB AAB TL 16");
ok(%quotes);
ok($quotes{"AAB AAB TL 16","success"});
ok($quotes{"AAB AAB TL 16","last"} > 0);


# Check that a bogus fund returns no-success.
%quotes = $quoter->aex("BOGUS");
ok( ! $quotes{"BOGUS","success"});
