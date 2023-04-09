#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 13;

my $q      = Finance::Quote->new("Deka");
$q->timeout(60);

my $year = (localtime())[5] + 1900;
my $lastyear = $year - 1;
my @stocks = ("DE0008474511","LU0051755006");
my %quotes = $q->deka(@stocks, "BOGUS");
ok(%quotes);

foreach my $stock (@stocks) {
  ok($quotes{$stock,"success"});
  ok($quotes{$stock,"last"} > 0);
  ok(substr($quotes{$stock,"isodate"},0,4) == $year ||
       substr($quotes{$stock,"isodate"},0,4) == $lastyear);
  ok(substr($quotes{$stock,"date"},6,4) == $year ||
       substr($quotes{$stock,"date"},6,4) == $lastyear);
}
ok($quotes{"DE0008474511","currency"} eq "EUR");
ok($quotes{"LU0051755006","currency"} eq "USD");


# Check that a bogus fund returns no-success.
ok($quotes{"BOGUS","success"} == 0);
ok($quotes{"BOGUS","errormsg"} eq "No data returned");
