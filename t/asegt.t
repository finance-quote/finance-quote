#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 10;

# Test za_unittrusts functions.

my $q      = Finance::Quote->new();
my $year   = (localtime())[5] + 1900;
my $lastyear = $year - 1;

my %quotes = $q->za_unittrusts("15740");
ok(%quotes);

# Check the last values are defined.  These are the most used and most
# reliable indicators of success.
ok($quotes{"15740","last"} > 0);
ok($quotes{"15740","success"});
ok(substr($quotes{"15740","date"},6,4) == $year ||
   substr($quotes{"15740","date"},6,4) == $lastyear);

# Exercise the fetch function a little.
%quotes = $q->fetch("za_unittrusts","15740");
ok(%quotes);
ok($quotes{"15740","last"} > 0);
ok($quotes{"15740","success"} > 0);

# Check that we're getting currency information.
ok($quotes{"15740", "currency"} eq "ZAR");

# Check we're not getting bogus percentage signs.
$quotes{"15740","p_change"} ||= "";	# Avoid warning if undefined.
ok($quotes{"15740","p_change"} !~ /%/);

# Check that looking up a bogus stock returns failure:
%quotes = $q->za_unittrusts("BOGUS");
ok(! $quotes{"BOGUS","success"});
