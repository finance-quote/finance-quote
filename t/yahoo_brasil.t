#!/usr/bin/perl -w
use strict;
use Test;
use Data::Dumper;
BEGIN {plan tests => 16};

use Finance::Quote;

# Test Yahoo_europe functions.

my $q      = Finance::Quote->new();
my @stocks = ("BRGE1","BAZA3");
my $year   = (localtime())[5] + 1900;
my $lastyear = $year - 1;

my %quotes = $q->fetch("yahoo_brasil", @stocks);
ok(%quotes);

# Check the nav values are defined.  These are the most
#  used and most reliable indicators of success.
foreach my $stock (@stocks) {
    ok($quotes{$stock,"success"});
    ok($quotes{$stock,"last"} > 0);
    ok(length($quotes{$stock,"name"}) > 0);
    ok($quotes{$stock, "currency"} eq "BRL");
    ok((substr($quotes{$stock,"isodate"},0,4) == $year) ||
       (substr($quotes{$stock,"isodate"},0,4) == $lastyear));
    ok((substr($quotes{$stock,"date"},6,4) == $year) ||
       (substr($quotes{$stock,"date"},6,4) == $lastyear));

    # Make sure we don't have spurious % signs.
    ok($quotes{$stock,"p_change"} !~ /%/);
}

# Check that a bogus stock returns no-success.
%quotes = $q->yahoo_brasil("BOGUS");
ok(! $quotes{"BOGUS","success"});
