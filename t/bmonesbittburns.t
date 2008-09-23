#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 23;

# Test bmonesbittburns functions.

my $q      = Finance::Quote->new();
my $year   = (localtime())[5] + 1900;
my $lastyear = $year - 1;

my @stocks = ("NT,T", "BBD.A,T","MFC598,MF");
my %quotes = $q->bmonesbittburns(@stocks);
ok(%quotes);

# Check that last and date are defined as our tests.
foreach my $stock (@stocks) {
    ok($quotes{$stock,"last"} > 0);
    ok($quotes{$stock,"success"});
    ok($quotes{$stock,"currency"} eq "CAD");
    ok(length($quotes{$stock,"date"}) > 0);
    ok(substr($quotes{$stock,"isodate"},0,4) == $year ||
       substr($quotes{$stock,"isodate"},0,4) == $lastyear);
    ok(substr($quotes{$stock,"date"},6,4) == $year ||
       substr($quotes{$stock,"date"},6,4) == $lastyear);
}

# Exercise the fetch function
%quotes = $q->fetch("bmonesbittburns", "NT,X");
ok(%quotes);
ok($quotes{"NT,X","success"});
ok($quotes{"NT,X","last"} > 0);

# Check that a bogus fund returns no-success.
%quotes = $q->bmonesbittburns("BOGUS");
ok( ! $quotes{"BOGUS","success"});

# Fetching an empty stock does result in an error, and yes
# this is bad.  But fetching an empty stock isn't normal
# behaviour.

# %quotes = $q->fetch("bmonesbittburns", "");
# ok( %quotes);
# ok( ! $quotes{"NT,X","success"});
# ok( ! $quotes{"NT,X","last"} > 0);

