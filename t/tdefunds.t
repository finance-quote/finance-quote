#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 5;

my $q = Finance::Quote->new;
ok($q);

my %quotes = $q->tdefunds("TD Canadian Index");

ok(%quotes);
ok($quotes{"TD Canadian Index", "nav"});

my $year = (localtime())[5] + 1900;
my $lastyear = $year - 1;
ok(substr($quotes{"TD Canadian Index","isodate"},0,4) == $year ||
   substr($quotes{"TD Canadian Index","isodate"},0,4) == $lastyear);
ok(substr($quotes{"TD Canadian Index","date"},6,4) == $year ||
   substr($quotes{"TD Canadian Index","date"},6,4) == $lastyear);
