#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 7;

# Test TD Waterhouse functions.

my $q      = Finance::Quote->new();

my %quotes = $q->unionfunds("975792","12345");
ok(%quotes);

# Check the last values are defined.  These are the most
#  used and most reliable indicators of success.
TODO: {
  local $TODO="This test probably only fails on non-business days since quotes are then set to 0 on the source";
  ok($quotes{"975792","last"} > 0);
}
ok($quotes{"975792","success"});
ok($quotes{"975792", "currency"} eq "EUR");

my $year = (localtime())[5] + 1900;
my $lastyear = $year - 1;
ok(substr($quotes{"975792","isodate"},0,4) eq $year ||
   substr($quotes{"975792","isodate"},0,4) eq $lastyear);
ok(substr($quotes{"975792","date"},6,4) eq $year ||
   substr($quotes{"975792","date"},6,4) eq $lastyear);


# Check that bogus stocks return failure:

ok(! $quotes{"12345","success"});
