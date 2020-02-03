#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
  plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

my $q      = Finance::Quote->new();
my $year   = (localtime())[5] + 1900;
my $lastyear = $year - 1;

plan tests => 8;

my @funds = ("OD-HORIA.OSE", "BOGUS");

my %quotes = $q->fetch("Oslobors", @funds);
ok(%quotes);

ok($quotes{"OD-HORIA.OSE", "price"} ne "");
ok(length($quotes{"OD-HORIA.OSE", "symbol"}) > 0);
ok($quotes{"OD-HORIA.OSE", "success"});
ok($quotes{"OD-HORIA.OSE", "currency"} eq "NOK");

my $isoyear = substr($quotes{"OD-HORIA.OSE", "isodate"}, 0, 4);
my $dateyear = substr($quotes{"OD-HORIA.OSE", "date"}, 6, 4);

ok($isoyear == $year  || $isoyear == $lastyear);
ok($dateyear == $year || $dateyear == $lastyear);

ok(! $quotes{"BOGUS", "success"});

