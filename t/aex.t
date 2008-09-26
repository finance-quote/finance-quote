#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 23;

# Test AEX functions.

my $quoter = Finance::Quote->new();

my %quotes = $quoter->aex("AAB A NEDERLANDCRT");
ok(%quotes);

# Check that some values are defined.
ok($quotes{"AAB A NEDERLANDCRT","success"});
ok($quotes{"AAB A NEDERLANDCRT","last"} > 0);
ok($quotes{"AAB A NEDERLANDCRT","date"});
ok($quotes{"AAB A NEDERLANDCRT","volume"} > 0);

my $year = (localtime())[5] + 1900;
my $lastyear = $year - 1;
ok(substr($quotes{"AAB A NEDERLANDCRT","isodate"},0,4) == $year ||
   substr($quotes{"AAB A NEDERLANDCRT","isodate"},0,4) == $lastyear);
ok(substr($quotes{"AAB A NEDERLANDCRT","date"},6,4) == $year ||
   substr($quotes{"AAB A NEDERLANDCRT","date"},6,4) == $lastyear);

# Exercise the fetch function 
%quotes = $quoter->fetch("aex","AAB AEX Click Perp.");
ok(%quotes);
ok($quotes{"AAB AEX Click Perp.","success"});
ok($quotes{"AAB AEX Click Perp.","last"} > 0);

# Test options fetching
# the following tests will fail after Dec 2009:-(
%quotes = $quoter->fetch("aex_options", "aex c dec 2009 400.00", "phi");
ok(%quotes);

# if next test fails look at following link if there's still a call
# option at the queried price available.
# http://www.aex.nl/scripts/marktinfo/OptieKoersen.asp?taal=en&a=1&Symbool=aex
ok($quotes{"aex c dec 2009 400.00","success"});
ok($quotes{"aex c dec 2009 400.00","close"} > 0);
#ok($quotes{"aex c dec 2009 400.00","bid"});	# May or may not exist
#ok($quotes{"aex c dec 2009 400.00","ask"});	# May or may not exist

ok($quotes{"phi","success"});
ok($quotes{"phi","options"});
ok($quotes{ $quotes{"phi","options"}->[0],"close"});
ok($quotes{ $quotes{"phi","options"}->[0],"date"});

# Test futures fetching
%quotes = $quoter->fetch("aex_futures", "fti");
ok(%quotes);

# Check that some values are defined.
ok($quotes{"fti","success"});
ok($quotes{"fti","futures"});
ok($quotes{ $quotes{"fti","futures"}->[0],"last"} > 0);
ok($quotes{ $quotes{"fti","futures"}->[0],"date"});

# Check that a bogus fund returns no-success.
%quotes = $quoter->aex("BOGUS");
ok( ! $quotes{"BOGUS","success"});
