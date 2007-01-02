#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 18};

use Finance::Quote;

# Test FTPortfolios functions.

my $q      = Finance::Quote->new();
my $year   = (localtime())[5] + 1900;
my $lastyear = $year - 1;

my @stocks = ("FKYMRX", "FAEDEX");
my %quotes = $q->ftportfolios(@stocks, "BOGUS");
ok(%quotes);

# Check that last and date are defined as our tests.
foreach my $stock (@stocks) {
    ok($quotes{$stock,"pop"} > 0);
    ok($quotes{$stock,"nav"} > 0);
    ok($quotes{$stock,"price"} > 0);
    ok($quotes{$stock,"success"});
    ok($quotes{$stock,"currency"} eq "USD");
    ok(length($quotes{$stock,"date"}) > 0);
    ok(substr($quotes{$stock,"isodate"},0,4) == $year ||
       substr($quotes{$stock,"isodate"},0,4) == $lastyear);
    ok(substr($quotes{$stock,"date"},6,4) == $year ||
       substr($quotes{$stock,"date"},6,4) == $lastyear);
}

# Check that a bogus fund returns no-success.
ok( ! $quotes{"BOGUS","success"});
