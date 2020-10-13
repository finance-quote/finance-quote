#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

# Test IndiaMutual functions.

my $q      = Finance::Quote->new();
my @funds = ("102676", "103131", "101599", 
	     "INF194K01W88", "INF090I01FN7", "INF082J01127");
my $year = (localtime())[5] + 1900;
my $lastyear = $year - 1;

plan tests => 6*@funds + 2;

my %quotes = $q->fetch("indiamutual", @funds);
ok(%quotes);

# Check that the name and nav are defined for all of the funds.
foreach my $fund (@funds) {
	ok($quotes{$fund,"nav"} > 0);
	ok(length($quotes{$fund,"name"}));
	ok($quotes{$fund,"success"});
        ok($quotes{$fund, "currency"} eq "INR");
	ok(substr($quotes{$fund,"isodate"},0,4) == $year ||
	   substr($quotes{$fund,"isodate"},0,4) == $lastyear);
	ok(substr($quotes{$fund,"date"},6,4) == $year ||
	   substr($quotes{$fund,"date"},6,4) == $lastyear);
}

# Check that a bogus fund returns no-success.
%quotes = $q->fetch("indiamutual", "BOGUS");
ok(! $quotes{"BOGUS","success"});
