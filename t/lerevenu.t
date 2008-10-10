#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 32;

# Test LeRevenu functions.

my $q      = Finance::Quote->new();

# my stocks = stock, fund, warrant, bond, indice
my @stocks = ("AF","FR0000441677","FR0010324475","FR0010112052","FR0003500008");

# LeRevenu tests need to cover all the possible cases:
#
#    Name		What		Test Case
#
#    Actions		Stock		AF
#    Obligations	Bond		FR0010112052
#    SICAVetFCP		Fund		FR0000441677
#    Bons&Warrants	Warrant		FR0010324475
#    Indices		Index		FR0003500008


my $year = (localtime())[5] + 1900;
my $lastyear = $year - 1;

my %quotes = $q->fetch("lerevenu", @stocks);
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
%quotes = $q->fetch("lerevenu", "BOGUS");
ok(! $quotes{"BOGUS","success"});
