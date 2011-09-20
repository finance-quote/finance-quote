#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 65;

# Test Bourso functions.

my $q      = Finance::Quote->new();

# my stocks = stock, fund, warrant, bond, indice
my @stocks = (
	"FR0000441677", # Fund
	"AF", # Stock, EUR, Nyse Euronext
	"MSFT", # Stock, USD, NASDAQ
	"SOLB", # Stock, EUR, BRUXELLES
	"CNP", # Stock, EUR, Nyse Euronext
	"FR0010371401", # Bond
	"FR0010707414", # Warrant
	"FR0003500008", # Index
);


# Bourso tests need to cover all the possible cases:
#
#    Name		What		Test Case
#
#    cours-action	Stock		AF
#    cours-obligation	Bond		FR0010371401
#    opcvm/opcvm	Fund		FR0000441677
#    cours-warrant	Warrant		FR0010707414
#    cours-indice	Index		FR0003500008

my $year = (localtime())[5] + 1900;
my $lastyear = $year - 1;

my %quotes;
#my %quotes = $q->fetch("bourso", @stocks);
#ok(%quotes);

# Check that the name, last, currency and date are defined for all of the stocks.
foreach my $stock (@stocks) {
  eval{
  %quotes = $q->fetch("bourso", $stock);
  ok(%quotes);

  ok($quotes{$stock,"last"} > 0);
  ok(length($quotes{$stock,"name"}));
  ok(length($quotes{$stock,"symbol"}));
  ok($quotes{$stock,"success"});
  ok( # indexes are quoted in percents
	  ($stock eq "FR0003500008") ||
	  (($stock eq "MSFT") && ($quotes{$stock, "currency"} eq "USD")) ||
	  ($quotes{$stock, "currency"} eq "EUR") );
  ok(substr($quotes{$stock,"isodate"},0,4) == $year ||
       substr($quotes{$stock,"isodate"},0,4) == $lastyear);
  ok(substr($quotes{$stock,"date"},6,4) == $year ||
       substr($quotes{$stock,"date"},6,4) == $lastyear);
  };
  if ($@){
    print STDERR "Error fetching stock ", $stock, "\n", $@;
    ok(!1);
  };
}

# Check that a bogus stock returns no-success.
%quotes = $q->fetch("bourso", "BOGUS");
ok(! $quotes{"BOGUS","success"});
