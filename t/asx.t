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
ok( %quotes, "Data returned for call to asx" );

# Check the last values are defined.  These are the most used and most
# reliable indicators of success.
ok( $quotes{"WES","success"}, "WES query was successful" );
cmp_ok( $quotes{"WES","last"}, '>', 0
      , "Last price for WES was > 0" );
ok( $quotes{"BHP","success"}, "BHP query was successful" );
cmp_ok( $quotes{"BHP","last"}, '>', 0
      , "Last price for BHP was > 0" );

# Exercise the fetch function a little.
%quotes = $q->fetch("asx","RZR");
ok( %quotes, "Data returned for call to fetch" );
ok( $quotes{"RZR","success"}, "RZR query was successful" );
cmp_ok( $quotes{"RZR","last"}, '>', 0
      , "Last price for RZR was > 0" );

# Check that we're getting currency information.
cmp_ok( $quotes{"RZR", "currency"}, "eq", "AUD"
      , "Currency of RZR is AUD" );

# Check we're not getting bogus percentage signs.
unlike( $quotes{"RZR","p_change"}
      , qr/%/
      , "No percentage sign in p_change value" );

# Check that looking up a bogus stock returns failure:
%quotes = $q->asx("BOG");
ok( ! $quotes{"BOG","success"}, "asx call for invalid stock returns failure");

