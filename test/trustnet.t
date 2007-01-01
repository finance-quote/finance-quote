#!/usr/bin/perl -w
use strict;
use Test;

BEGIN {plan tests => 12};

use Finance::Quote;

# Test trustnet functions.

my $q = Finance::Quote->new();
my $year = (localtime())[5] + 1900;
my $lastyear = $year - 1;

my @stocks = ("ABBEY NATIONAL INTERNATIONAL","MARLBOROUGH INTERNATIONAL EQUITY");

my %quotes = $q->fetch("trustnet",@stocks);

ok(%quotes);

# For each of our stocks, check to make sure we got back some
# useful information.

foreach my $stock (@stocks) {
	ok($quotes{$stock,"success"});
	ok($quotes{$stock,"price"});
	ok($quotes{$stock,"date"});
	ok(substr($quotes{$stock,"isodate"},0,4) == $year ||
	   substr($quotes{$stock,"isodate"},0,4) == $lastyear);
	ok(substr($quotes{$stock,"date"},6,4) == $year ||
	   substr($quotes{$stock,"date"},6,4) == $lastyear);
}

# Test that a bogus stock gets no success.

%quotes = $q->fetch("trustnet","BOGUS");
ok(! $quotes{"BOGUS","success"});
