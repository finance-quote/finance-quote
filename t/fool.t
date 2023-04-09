#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if ( not $ENV{"ONLINE_TEST"} ) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

my $q        = Finance::Quote->new();
my $year     = (localtime())[5] + 1900;
my $lastyear = $year - 1;

my @symbols =  qw/MSFT AMZN AAPL GOOGL GOOG FB CSCO INTC PEP BRK-A SEB NVR BKNG IBKR/;

plan tests => 11*(1+$#symbols)+2;

my %quotes = $q->fool(@symbols, "BOGUS");
ok(%quotes);

foreach my $symbol (@symbols) {
  ok($quotes{$symbol, "symbol"} eq $symbol, "$symbol defined");
  ok($quotes{$symbol, "success"}, "$symbol success");
  ok($quotes{$symbol, "day_range"} =~ m/^[0-9.]+\s*-\s*[0-9.]+$/, "$symbol returned day_range");
  ok($quotes{$symbol, "open"} > 0, "$symbol returned open");
  ok($quotes{$symbol, "volume"} >= 0, "$symbol returned volume");
  ok($quotes{$symbol, "close"} > 0, "$symbol returned close");
  ok($quotes{$symbol, "year_range"} =~ m/^[0-9.]+\s*-\s*[0-9.]+$/, "$symbol returned year_range");
  ok($quotes{$symbol, "last"} > 0, "$symbol returned last");
  ok($quotes{$symbol, "currency"} eq 'USD', "$symbol returned currency");
  ok(substr($quotes{$symbol, "isodate"}, 0, 4) == $year
      || substr($quotes{$symbol, "isodate"}, 0, 4) == $lastyear);
  ok(substr($quotes{$symbol, "date"}, 6, 4) == $year
      ||substr($quotes{$symbol, "date"}, 6, 4) == $lastyear);
}

ok(!$quotes{"BOGUS", "success"});

