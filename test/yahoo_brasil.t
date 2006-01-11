#!/usr/bin/perl -w
use strict;
use Test;
use Data::Dumper;
BEGIN {plan tests => 8};

use Finance::Quote;

# Test Yahoo_europe functions.

my $q      = Finance::Quote->new();
my $year   = (localtime())[5] + 1900;
my $lastyear = $year - 1;

my %quotes = $q->yahoo_brasil("VULC3","BOGUS");
ok(%quotes);

# Check the nav values are defined.  These are the most
#  used and most reliable indicators of success.
#ok($quotes{"VULC3","last"} > 0);
ok(length($quotes{"VULC3","name"}) > 0);
ok($quotes{"VULC3","success"});
ok($quotes{"VULC3", "currency"} eq "BRL");
ok((substr($quotes{"VULC3","isodate"},0,4) == $year) ||
   (substr($quotes{"VULC3","isodate"},0,4) == $lastyear));
ok((substr($quotes{"VULC3","date"},6,4) == $year) ||
   (substr($quotes{"VULC3","date"},6,4) == $lastyear));

# Make sure we don't have spurious % signs.

ok($quotes{"VULC3","p_change"} !~ /%/);

# Check that a bogus stock returns no-success.
ok(! $quotes{"BOGUS","success"});
