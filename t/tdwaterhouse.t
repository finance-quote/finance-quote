#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 12;

# Test TD Waterhouse functions.

my $q      = Finance::Quote->new();
my $year   = (localtime())[5] + 1900;
my $lastyear = $year - 1;

my @stocks = ("TD U.S. MidCap Growth US", "TD Canadian Bond Index");

my %quotes = $q->tdwaterhouse(@stocks, "BOGUS");
ok(%quotes);

# Check the last values are defined.  These are the most
#  used and most reliable indicators of success.
foreach my $stock (@stocks) {
    ok($quotes{$stock,"last"} > 0);
    ok($quotes{$stock,"success"});
    ok(substr($quotes{$stock,"isodate"},0,4) == $year ||
       substr($quotes{$stock,"isodate"},0,4) == $lastyear);
    ok(substr($quotes{$stock,"date"},6,4) == $year ||
       substr($quotes{$stock,"date"},6,4) == $lastyear);
}

ok($quotes{"TD U.S. MidCap Growth US", "currency"} eq "USD");
ok($quotes{"TD Canadian Bond Index", "currency"} eq "CAD");

# Check that bogus stocks return failure:

ok(! $quotes{"BOGUS","success"});
