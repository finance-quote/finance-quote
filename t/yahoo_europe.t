#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 21;

# Test Yahoo_europe functions.

my $q      = Finance::Quote->new();
my $year   = (localtime())[5] + 1900;
my $lastyear = $year - 1;

my %quotes = $q->yahoo_europe("UG.PA","BOGUS.L");
ok(%quotes);

# Check the nav values are defined.  These are the most
#  used and most reliable indicators of success.
ok($quotes{"UG.PA","last"} > 0);
ok(length($quotes{"UG.PA","name"}) > 0);
ok($quotes{"UG.PA","success"});
ok($quotes{"UG.PA", "currency"} eq "EUR");
ok(substr($quotes{"UG.PA","isodate"},0,4) == $year ||
   substr($quotes{"UG.PA","isodate"},0,4) == $lastyear);
ok(substr($quotes{"UG.PA","date"},6,4) == $year ||
   substr($quotes{"UG.PA","date"},6,4) == $lastyear);

# Make sure we don't have spurious % signs.

ok($quotes{"UG.PA","p_change"} !~ /%/);

# Check that a bogus stock returns no-success.
ok(! $quotes{"BOGUS","success"});

# London stocks can be returned in a variety of currencies

my %londonquotes = $q->fetch("yahoo_europe","BAY.L");
ok($londonquotes{"BAY.L","success"});
ok($londonquotes{"BAY.L","currency"} eq "GBP");
ok(($londonquotes{"BAY.L","currency"} eq "GBP") &&
   !defined($londonquotes{"BAY.L","currency_set_by_fq"}));

%londonquotes = $q->fetch("yahoo_europe","CCR.L");
ok($londonquotes{"CCR.L","success"});
ok($londonquotes{"CCR.L","currency"} eq "EUR");
ok(($londonquotes{"CCR.L","currency"} eq "EUR") &&
   !defined($londonquotes{"CCR.L","currency_set_by_fq"}));

# Copenhangen stocks should be returned in Danisk Krone (DKK).

my %copenhagenquotes = $q->fetch("yahoo_europe","TDC.CO");
ok($copenhagenquotes{"TDC.CO","success"});
ok($copenhagenquotes{"TDC.CO","currency"} eq "DKK");
ok(($copenhagenquotes{"TDC.CO","currency"} eq "DKK") &&
   !defined($copenhagenquotes{"TDC.CO","currency_set_by_fq"}));

# Two stocks from the German XETRA.  One in EUR and one in USD.

my %xetraquotes = $q->fetch("yahoo_europe","DBK.DE", "ERM.DE");
ok($xetraquotes{"DBK.DE","success"});
ok($xetraquotes{"DBK.DE","currency"} eq "EUR");
ok(($xetraquotes{"DBK.DE","currency"} eq "EUR") &&
   !defined($xetraquotes{"DBK.DE","currency_set_by_fq"}));


