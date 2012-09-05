#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 11;

# Test currency conversion, both explicit requests and automatic
# conversion.

my $q      = Finance::Quote->new();

# Explicit conversion...
ok($q->currency("USD","AUD"));			# Test 1
ok($q->currency("EUR","JPY"));			# Test 2
ok(! defined($q->currency("XXX","YYY")));	# Test 3

# test for thousands : GBP -> IQD. This should be > 1000
ok($q->currency("GBP","IQD")>1000) ;            # Test 4

# Test 5
ok(($q->currency("10 AUD","AUD")) == (10 * ($q->currency("AUD","AUD"))));

# Euros into French Francs are fixed at a conversion rate of
# 1:6.559576 .  We can use this knowledge to test that a stock is
# converting correctly.

# Test 6
my %baseinfo = $q->fetch("yahoo_europe","UG.PA");
ok($baseinfo{"UG.PA","success"});

$q->set_currency("AUD");	# All new requests in Aussie Dollars.

my %info = $q->fetch("yahoo_europe","UG.PA");
ok($info{"UG.PA","success"});		# Test 7
ok($info{"UG.PA","currency"} eq "AUD");	# Test 8
ok($info{"UG.PA","price"} > 0);		# Test 9

# Check if inverse is working ok
ok(check_inverse("EUR","RUB"),"Inverse is calculated correctly: multiplication should be 1");
ok(check_inverse("CZK","USD"),"Inverse is calculated correctly: multiplication should be 1");

sub check_inverse {
    my ($cur1,$cur2)=@_;
    my $a = $q->currency($cur1,$cur2);
    my $b = $q->currency($cur2,$cur1);
    return $a*$b;
}
