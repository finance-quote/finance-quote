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

plan tests => 17;

my @funds = ("OD-HORIA.OSE", "DK-EUROP.OSE", "ST-VEKST.OSE");

my %quotes = $q->fetch("Oslobors", @funds);
ok(%quotes, "Data fetched");

foreach my $symbol (@funds) {
  ok($quotes{ $symbol, "success"}, "Retrieved $symbol");
  ok($quotes{ $symbol, "price"} ne "", "Price is defined");
  ok($quotes{ $symbol, "currency"} eq "NOK", "Currency is set to NOK");

  my $isoyear = substr($quotes{$symbol, "isodate"}, 0, 4);
  my $dateyear = substr($quotes{$symbol, "date"}, 6, 4);

  ok($isoyear == $year  || $isoyear == $lastyear, "ISODate is this or last year");
  ok($dateyear == $year || $dateyear == $lastyear, "Date is this or last year");
}

%quotes = $q->fetch("oslobors", "BOGUS");
ok( !$quotes{"BOGUS", "success"}, "BOGUS failed");
