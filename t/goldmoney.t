#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 16;

# Test GoldMoney functions.
my $q      = Finance::Quote->new("GoldMoney");
$q->set_currency('EUR');
my %quotes = $q->fetch("goldmoney","gold", "silver", "BOGUS");
ok(%quotes);

# Check that sound information is returned for gold and silver.
ok($quotes{"gold","success"});
ok($quotes{"gold","last"} > 0);
ok($quotes{"gold","currency"} eq "EUR");
ok(length($quotes{"gold","date"}) > 0);
ok(length($quotes{"gold","time"}) > 0);

ok($quotes{"silver","success"});
ok($quotes{"silver","last"} > 0);
ok($quotes{"silver","currency"} eq "EUR");
ok(length($quotes{"silver","date"}) > 0);
ok(length($quotes{"silver","time"}) > 0);

my $year = (localtime())[5] + 1900;
ok((substr($quotes{"gold","isodate"},0,4) == $year));
ok((substr($quotes{"gold","date"},6,4) == $year));
ok((substr($quotes{"silver","isodate"},0,4) == $year));
ok((substr($quotes{"silver","date"},6,4) == $year));

# Check that a bogus symbol returns no-success.
ok(! $quotes{"BOGUS","success"});

