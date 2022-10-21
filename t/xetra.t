#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 20;

# Test xetra functions.

my $q      = Finance::Quote->new();

my %quotes = $q->xetra("DE0008404005");
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

%quotes = $q->xetra("NL0011540547");
ok(%quotes);

ok($quotes{"NL0011540547","last"} > 0);
ok($quotes{"NL0011540547","success"});
ok($quotes{"NL0011540547", "currency"} eq "EUR");

ok(substr($quotes{"NL0011540547","isodate"},0,4) eq $year ||
   substr($quotes{"NL0011540547","isodate"},0,4) eq $lastyear);
ok(substr($quotes{"NL0011540547","date"},6,4) eq $year ||
   substr($quotes{"NL0011540547","date"},6,4) eq $lastyear);

%quotes = $q->xetra("FR0000120628");
ok(%quotes);

ok($quotes{"FR0000120628","last"} > 0);
ok($quotes{"FR0000120628","success"});
ok($quotes{"FR0000120628", "currency"} eq "EUR");




ok(substr($quotes{"FR0000120628","isodate"},0,4) eq $year ||
   substr($quotes{"FR0000120628","isodate"},0,4) eq $lastyear);
ok(substr($quotes{"FR0000120628","date"},6,4) eq $year ||
   substr($quotes{"FR0000120628","date"},6,4) eq $lastyear);   

# Check that bogus stocks return failure:
%quotes = $q->xetra("NL0011540547");
ok(%quotes);
ok(! $quotes{"12345","success"});
