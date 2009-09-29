#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 26;

# Test Bourso functions.

my $q      = Finance::Quote->new();

# my stocks = stock, fund, warrant, bond, indice
my @stocks = ("AF","MSFT","SOLB","CNP");


# Bourso tests need to cover all the possible cases:
#
#    Name		What		Test Case
#
#    cours-action	Stock		AF
#    cours-obligation	Bond		FR0010112052
#    opcvm/opcvm	Fund		FR0000441677
#    cours-warrant	Warrant		FR0010639880
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
  ok( ($stock eq "FR0010112052") ||  # bonds and indexes are quoted in percents
	  ($stock eq "FR0003500008") ||
	  (($stock eq "MSFT") && ($quotes{$stock, "currency"} eq "USD")) ||
	  ($quotes{$stock, "currency"} eq "EUR") );
  ok(substr($quotes{$stock,"isodate"},0,4) == $year ||
       substr($quotes{$stock,"isodate"},0,4) == $lastyear);
  ok(substr($quotes{$stock,"date"},6,4) == $year ||
       substr($quotes{$stock,"date"},6,4) == $lastyear);
}

# Check that a bogus stock returns no-success.
%quotes = $q->fetch("bourso", "BOGUS");
ok(! $quotes{"BOGUS","success"});
