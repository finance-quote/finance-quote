#!/usr/bin/perl -w
use strict;
use Test;
use Data::Dumper;
BEGIN {plan tests => 7};

use Finance::Quote;

# Test Yahoo_europe functions.

my $q      = Finance::Quote->new();

my %quotes = $q->yahoo_australia("BHP","BOGUS");
ok(%quotes);

# Check the nav values are defined.  These are the most
#  used and most reliable indicators of success.
ok($quotes{"BHP","last"} > 0);
ok(length($quotes{"BHP","name"}) > 0);
ok($quotes{"BHP","success"});
ok($quotes{"BHP", "currency"} eq "AUD");

# Make sure we don't have spurious % signs.

ok($quotes{"BHP","p_change"} !~ /%/);

# Check that a bogus stock returns no-success.
ok(! $quotes{"BOGUS","success"});
