#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 8;

# Test Fondsweb functions.

my $q      = Finance::Quote->new();
my $year   = (localtime())[5] + 1900;
my $lastyear = $year - 1;

my @stocks = ("LU0804734787","BOGUS");

my %quotes = $q->fetch("Fondsweb",@stocks);
ok(%quotes);

# Check the nav values are defined.  These are the most
#  used and most reliable indicators of success.
ok($quotes{"LU0804734787","nav"} ne "");
ok(length($quotes{"LU0804734787","name"}) > 0);
ok($quotes{"LU0804734787","success"});
ok($quotes{"LU0804734787", "currency"} eq "EUR");
ok(substr($quotes{"LU0804734787","isodate"},0,4) == $year ||
   substr($quotes{"LU0804734787","isodate"},0,4) == $lastyear);  
ok(substr($quotes{"LU0804734787","date"},6,4) == $year ||
   substr($quotes{"LU0804734787","date"},6,4) == $lastyear);

# Check that a bogus stock returns no-success.
ok(! $quotes{"LU0085995990","success"});

