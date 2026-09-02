#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if ( not $ENV{"ONLINE_TEST"} ) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

my $q        = Finance::Quote->new('NPSNAV');
my $year     = (localtime())[5] + 1900;
my $lastyear = $year - 1;

my @symbols =  qw/SM001001 SM001002 SM008001/;

plan tests => 9*(1+$#symbols)+2;

my %quotes = $q->npsnav(@symbols, "BOGUS");
ok(%quotes, "Successful quote retrieval");

foreach my $symbol (@symbols) {
  ok($quotes{$symbol, "symbol"} eq $symbol, "$symbol defined");
  ok($quotes{$symbol, "success"}, "$symbol success");
  ok($quotes{$symbol, "nav"} > 0, "$symbol returned nav");
  ok($quotes{$symbol, "currency"} eq 'INR', "$symbol returned currency");
  ok(substr($quotes{$symbol, "isodate"}, 0, 4) == $year
      || substr($quotes{$symbol, "isodate"}, 0, 4) == $lastyear, "$symbol returned valid isodate");
  ok(substr($quotes{$symbol, "date"}, 6, 4) == $year
      ||substr($quotes{$symbol, "date"}, 6, 4) == $lastyear, "$symbol returned valid date");
  ok ($quotes{$symbol, "Last Updated"});
  ok (defined ($quotes{$symbol, "PFM Code"}), "$symbol returned PFM Code");
  ok ($quotes{$symbol, "Scheme Code"} eq $symbol, "$symbol returned Scheme Code");
}

ok((!$quotes{"BOGUS", "success"}),'BOGUS failed as expected');

