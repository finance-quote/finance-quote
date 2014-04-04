#!/usr/bin/perl -w

# 16-Feb-2014 Change RZR (delisted in 2012) to BOQ.
# 28-Feb-2014 Add tests with 11 stocks at once. plan tests 11 -> 34.

use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 34;

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
%quotes = $q->fetch("asx","BOQ");
ok( %quotes, "Data returned for call to fetch" );
ok( $quotes{"BOQ","success"}, "BOQ query was successful" );
cmp_ok( $quotes{"BOQ","last"}, '>', 0
      , "Last price for BOQ was > 0" );

# Check that we're getting currency information.
cmp_ok( $quotes{"BOQ", "currency"}, "eq", "AUD"
      , "Currency of BOQ is AUD" );

# Check we're not getting bogus percentage signs.
unlike( $quotes{"BOQ","p_change"}
      , qr/%/
      , "No percentage sign in p_change value" );

# Check that looking up a bogus stock returns failure:
%quotes = $q->asx("BOG");
ok( ! $quotes{"BOG","success"}, "asx call for invalid stock BOG returns failure");

# Check 11 stocks at once to test batching of price enquiries into groups of 10
my @stocks = qw/AMP ANZ BHP BOQ BEN CSR IAG NAB TLS WBC WES/;

%quotes = $q->asx(@stocks);
ok( %quotes, "Data returned for call to asx" );

# Check the last values are defined.  These are the most used and most
# reliable indicators of success.

foreach my $stock (@stocks) {
	ok( $quotes{$stock, "success"}, $stock . " query was successful" );
	cmp_ok( $quotes{$stock,"last"}, '>', 0
	      , "Last price for " . $stock . " was > 0" );
}
