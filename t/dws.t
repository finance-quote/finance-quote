#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 8;

# Test DWS functions.

my $q      = Finance::Quote->new("DWS");

my %quotes = $q->fetch("dwsfunds","847402","BOGUS");
ok(%quotes);

# Check that the last and date values are defined.
ok($quotes{"847402","success"});
ok($quotes{"847402","last"} > 0);
ok(length($quotes{"847402","date"}) > 0);
ok($quotes{"847402","currency"} eq "EUR");

my $year = (localtime())[5] + 1900;
my $lastyear = $year - 1;
ok((substr($quotes{"847402","isodate"},0,4) == $year) ||
   (substr($quotes{"847402","isodate"},0,4) == $lastyear));
ok((substr($quotes{"847402","date"},6,4) == $year) ||
   (substr($quotes{"847402","date"},6,4) == $lastyear));

# Check that a bogus fund returns no-success.
ok(! $quotes{"BOGUS","success"});
