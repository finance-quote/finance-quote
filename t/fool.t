#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if ( not $ENV{"ONLINE_TEST"} ) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

my $q        = Finance::Quote->new('Fool');
my $year     = (localtime())[5] + 1900;
my $lastyear = $year - 1;

my @symbols =  qw/MSFT AMZN GOOG CSCO INTC PEP BRK.A SEB NVR BKNG/;

plan tests => 8*(1+$#symbols)+2;

my %quotes = $q->fool(@symbols, "BOGUS");
ok(%quotes, "Successful quote retrieval");

foreach my $symbol (@symbols) {
  ok($quotes{$symbol, "symbol"} eq $symbol, "$symbol defined");
  ok($quotes{$symbol, "success"}, "$symbol success");
  ok($quotes{$symbol, "open"} > 0, "$symbol returned open");
  ok($quotes{$symbol, "volume"} >= 0, "$symbol returned volume");
  ok($quotes{$symbol, "last"} > 0, "$symbol returned last");
  ok($quotes{$symbol, "currency"} eq 'USD', "$symbol returned currency");
  ok(substr($quotes{$symbol, "isodate"}, 0, 4) == $year
      || substr($quotes{$symbol, "isodate"}, 0, 4) == $lastyear, "$symbol returned valid isodate");
  ok(substr($quotes{$symbol, "date"}, 6, 4) == $year
      ||substr($quotes{$symbol, "date"}, 6, 4) == $lastyear, "$symbol returned valid date");
}

ok((!$quotes{"BOGUS", "success"}),'BOGUS failed as expected');

