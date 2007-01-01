#!/usr/bin/perl -w
use strict;
use Test;
use Data::Dumper;
BEGIN {plan tests => 9};

use Finance::Quote;

# Test Yahoo_nz functions.

my $q      = Finance::Quote->new();
my $year   = (localtime())[5] + 1900;
my $lastyear = $year - 1;

my %quotes = $q->yahoo_nz("AIA","BOGUS");
ok(%quotes);

# Check the nav values are defined.  These are the most
#  used and most reliable indicators of success.
ok($quotes{"AIA","last"} > 0);
ok(length($quotes{"AIA","name"}) > 0);
ok($quotes{"AIA","success"});
ok($quotes{"AIA", "currency"} eq "NZD");
ok(substr($quotes{"AIA","isodate"},0,4) == $year ||
   substr($quotes{"AIA","isodate"},0,4) == $lastyear);
ok(substr($quotes{"AIA","date"},6,4) == $year ||
   substr($quotes{"AIA","date"},6,4) == $lastyear);

# Make sure we don't have spurious % signs.

ok($quotes{"AIA","p_change"} !~ /%/);

# Check that a bogus stock returns no-success.
ok(! $quotes{"BOGUS","success"});
