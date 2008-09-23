#!/usr/bin/perl -w
use strict;
use Test;
use Data::Dumper;
BEGIN {plan tests => 9};

use Finance::Quote;

# Test Yahoo_europe functions.

my $q      = Finance::Quote->new();
my $year   = (localtime())[5] + 1900;
my $lastyear = $year - 1;

my %quotes = $q->yahoo_australia("BHP","BOGUS");
ok(%quotes);

# Check the nav values are defined.  These are the most
#  used and most reliable indicators of success.
ok($quotes{"BHP","last"} > 0);
ok(length($quotes{"BHP","name"}) > 0);
ok($quotes{"BHP","success"});
ok($quotes{"BHP", "currency"} eq "AUD");
ok(substr($quotes{"BHP","isodate"},0,4) == $year ||
   substr($quotes{"BHP","isodate"},0,4) == $lastyear);
ok(substr($quotes{"BHP","date"},6,4) == $year ||
   substr($quotes{"BHP","date"},6,4) == $lastyear);

# Make sure we don't have spurious % signs.

ok($quotes{"BHP","p_change"} !~ /%/);

# Check that a bogus stock returns no-success.
ok(! $quotes{"BOGUS","success"});
