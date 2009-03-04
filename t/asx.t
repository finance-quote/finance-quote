#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 11;

# Test ASX functions.

my $q      = Finance::Quote->new();

$q->timeout(120);	# ASX is broken regularly, so timeouts are good.

my %quotes = $q->asx("WES","BHP");
ok(%quotes);

# Check the last values are defined.  These are the most used and most
# reliable indicators of success.
ok($quotes{"WES","last"} > 0);
ok($quotes{"WES","success"});
ok($quotes{"BHP","last"} > 0);
ok($quotes{"BHP","success"});

# Exercise the fetch function a little.
%quotes = $q->fetch("asx","RZR");
ok(%quotes);
ok($quotes{"RZR","last"} > 0);
ok($quotes{"RZR","success"} > 0);

# Check that we're getting currency information.
ok($quotes{"RZR", "currency"} eq "AUD");

# Check we're not getting bogus percentage signs.
$quotes{"RZR","p_change"} ||= "";	# Avoid warning if undefined.
ok($quotes{"RZR","p_change"} !~ /%/);

# Check that looking up a bogus stock returns failure:
%quotes = $q->asx("BOG");
ok(! $quotes{"BOG","success"});

