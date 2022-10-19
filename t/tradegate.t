#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 7;

# Test Tradegate functions.

my $q      = Finance::Quote->new();

my %quotes = $q->tradegate("DE0008404005","12345");
ok(%quotes);

# Check the last values are defined.  These are the most
#  used and most reliable indicators of success.
ok($quotes{"DE0008404005","last"} > 0);
ok($quotes{"DE0008404005","success"});
ok($quotes{"DE0008404005", "currency"} eq "EUR");

my $year = (localtime())[5] + 1900;
my $lastyear = $year - 1;
ok(substr($quotes{"DE0008404005","isodate"},0,4) eq $year ||
   substr($quotes{"DE0008404005","isodate"},0,4) eq $lastyear);
ok(substr($quotes{"DE0008404005","date"},6,4) eq $year ||
   substr($quotes{"DE0008404005","date"},6,4) eq $lastyear);


# Check that bogus stocks return failure:

ok(! $quotes{"12345","success"});
