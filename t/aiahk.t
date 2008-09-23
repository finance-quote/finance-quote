#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 30};

use Finance::Quote;

# Test Aia functions.

my $q      = Finance::Quote->new();

# my stocks = stock, fund, warrant, bond, indice
my @stocks = ("ABD-AUS.EQ", "AIG-EUSC.U", "FID-JP.ADV", "SCH-HKEQ");

my $year = (localtime())[5] + 1900;
my $lastyear = $year - 1;

my %quotes = $q->fetch("aiahk", @stocks);
ok(%quotes);

# Check that the name, last, currency and date are defined for all of the stocks.
foreach my $stock (@stocks) {
	ok($quotes{$stock,"success"});
	ok($quotes{$stock,"bid"} > 0);
	ok($quotes{$stock,"offer"} > 0);
	ok(length($quotes{$stock,"name"}));
	ok(substr($quotes{$stock,"isodate"},0,4) == $year ||
	   substr($quotes{$stock,"isodate"},0,4) == $lastyear);
	ok(substr($quotes{$stock,"date"},6,4) == $year ||
	   substr($quotes{$stock,"date"},6,4) == $lastyear);
}
ok($quotes{"ABD-AUS.EQ", "currency"} eq "AUD");
ok($quotes{"AIG-EUSC.U", "currency"} eq "EUR");
ok($quotes{"FID-JP.ADV", "currency"} eq "JPY");
ok($quotes{"SCH-HKEQ", "currency"}   eq "HKD");

# Check that a bogus stock returns no-success.
%quotes = $q->fetch("aiahk", "BOGUS");
ok(! $quotes{"BOGUS","success"});
