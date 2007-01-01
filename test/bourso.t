#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 32};

use Finance::Quote;

# Test Bourso functions.

my $q      = Finance::Quote->new();

# my stocks = stock, fund, warrant, bond, indice
my @stocks = ("AF","FR0000441677","FR0010324475","FR0010112052","FR0003500008");

# Bourso tests need to cover all the possible cases:
#
#    Name		What		Test Case
#
#    cours-action	Stock		AF
#    cours-obligation	Bond		FR0010112052
#    opcvm/opcvm	Fund		FR0000441677
#    cours-warrant	Warrant		FR0010324475
#    cours-indice	Index		FR0003500008

my $year = (localtime())[5] + 1900;
my $lastyear = $year - 1;

my %quotes = $q->fetch("bourso", @stocks);
ok(%quotes);

# Check that the name, last, currency and date are defined for all of the stocks.
foreach my $stock (@stocks) {
	ok($quotes{$stock,"last"} > 0);
	ok(length($quotes{$stock,"name"}));
	ok($quotes{$stock,"success"});
        ok($quotes{$stock, "currency"} eq "EUR");
	ok(substr($quotes{$stock,"isodate"},0,4) == $year ||
	   substr($quotes{$stock,"isodate"},0,4) == $lastyear);
	ok(substr($quotes{$stock,"date"},6,4) == $year ||
	   substr($quotes{$stock,"date"},6,4) == $lastyear);
}

# Check that a bogus stock returns no-success.
%quotes = $q->fetch("bourso", "BOGUS");
ok(! $quotes{"BOGUS","success"});
