#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 17;

# Test Fidelity functions.

my $q      = Finance::Quote->new();
my @funds = qw/59333PRJ9 971175PC2 594712RK9/;
my $year = (localtime())[5] + 1900;
my $lastyear = $year - 1;

my %quotes = $q->fetch("fidelityfixed",@funds);
ok(%quotes);

# Check info reported by funds
foreach my $fund (@funds) {
	ok(length($quotes{$fund,"name"}));
	ok($quotes{$fund,"success"});
        ok($quotes{$fund, "currency"} eq "USD");
	ok(substr($quotes{$fund,"isodate"},0,4) == $year ||
	   substr($quotes{$fund,"isodate"},0,4) == $lastyear);
	ok(substr($quotes{$fund,"date"},6,4) == $year ||
	   substr($quotes{$fund,"date"},6,4) == $lastyear);
}

# Check that a bogus fund returns no-success.
%quotes = $q->fetch("fidelityfixed","BOGUS");
ok(! $quotes{"BOGUS","success"});
