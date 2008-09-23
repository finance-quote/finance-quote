#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 26;

# Test Vanguard functions.

my $q      = Finance::Quote->new();
my $year = (localtime())[5] + 1900;
my $lastyear = $year - 1;
my @funds = qw/VBINX VIVAX VWINX VFIIX/;

my %quotes = $q->vanguard(@funds);
ok(%quotes);

# Check that the name and last are defined for all of the funds.
foreach my $fund (@funds) {
	ok($quotes{$fund,"last"} > 0);
	ok(length($quotes{$fund,"name"}));
	ok($quotes{$fund,"success"});
        ok($quotes{$fund, "currency"} eq "USD");
	ok(substr($quotes{$fund,"isodate"},0,4) == $year ||
	   substr($quotes{$fund,"isodate"},0,4) == $lastyear);
	ok(substr($quotes{$fund,"date"},6,4) == $year ||
	   substr($quotes{$fund,"date"},6,4) == $lastyear);
}

# Make sure we're not getting spurious percentage signs.

ok($quotes{"VBINX","p_change"} !~ /%/);
