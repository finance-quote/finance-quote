#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 8;

# Test currency conversion, both explicit requests and automatic
# conversion.

my $q      = Finance::Quote->new();

# Explicit conversion...
ok($q->currency("USD","AUD"));			# Test 1
ok($q->currency("EUR","JPY"));			# Test 2
ok(! defined($q->currency("XXX","YYY")));	# Test 3

# Test 4
ok(($q->currency("10 AUD","AUD")) == (10 * ($q->currency("AUD","AUD"))));

# Euros into French Francs are fixed at a conversion rate of
# 1:6.559576 .  We can use this knowledge to test that a stock is
# converting correctly.

# Test 5
my %baseinfo = $q->fetch("europe","UG.PA");
ok($baseinfo{"UG.PA","success"});

$q->set_currency("AUD");	# All new requests in Aussie Dollars.

my %info = $q->fetch("europe","UG.PA");
ok($info{"UG.PA","success"});		# Test 6
ok($info{"UG.PA","currency"} eq "AUD");	# Test 7
ok($info{"UG.PA","price"} > 0);		# Test 8
