#!/usr/bin/perl -w
use strict;
use Test;
use Data::Dumper;
BEGIN {plan tests => 21};

use Finance::Quote;

# Test Yahoo_europe functions.

my $q      = Finance::Quote->new();
my $year   = (localtime())[5] + 1900;

my %quotes = $q->yahoo_europe("12150.PA","BOGUS.L");
ok(%quotes);

# Check the nav values are defined.  These are the most
#  used and most reliable indicators of success.
ok($quotes{"12150.PA","last"} > 0);
ok(length($quotes{"12150.PA","name"}) > 0);
ok($quotes{"12150.PA","success"});
ok($quotes{"12150.PA", "currency"} eq "EUR");
ok(substr($quotes{"12150.PA","isodate"},0,4) == $year);
ok(substr($quotes{"12150.PA","date"},6,4) == $year);

# Make sure we don't have spurious % signs.

ok($quotes{"12150.PA","p_change"} !~ /%/);

# Check that a bogus stock returns no-success.
ok(! $quotes{"BOGUS","success"});

# London stocks should be returned in British Pounds (GBP).

my %londonquotes = $q->fetch("yahoo_europe","BAY.L");
ok($londonquotes{"BAY.L","success"});
ok($londonquotes{"BAY.L","currency"} eq "GBP");
ok(($londonquotes{"BAY.L","currency"} eq "GBP") &&
   !defined($londonquotes{"BAY.L","currency_set_by_fq"}));

# Copenhangen stocks should be returned in Danisk Krone (DKK).

my %copenhagenquotes = $q->fetch("yahoo_europe","TDC.CO");
ok($copenhagenquotes{"TDC.CO","success"});
ok($copenhagenquotes{"TDC.CO","currency"} eq "DKK");
ok(($copenhagenquotes{"TDC.CO","currency"} eq "DKK") &&
   !defined($copenhagenquotes{"TDC.CO","currency_set_by_fq"}));

# Two stocks from the German XETRA.  One in EUR and one in USD.

my %xetraquotes = $q->fetch("yahoo_europe","632034.DE", "973348.DE");
ok($xetraquotes{"632034.DE","success"});
ok($xetraquotes{"632034.DE","currency"} eq "EUR");
ok(($xetraquotes{"632034.DE","currency"} eq "EUR") &&
   !defined($xetraquotes{"632034.DE","currency_set_by_fq"}));
ok($xetraquotes{"973348.DE","success"});
ok($xetraquotes{"973348.DE","currency"} eq "USD");
ok(($xetraquotes{"973348.DE","currency"} eq "USD") &&
   !defined($xetraquotes{"973348.DE","currency_set_by_fq"}));


