#!/usr/bin/perl -w
use strict;
use Test;
use Data::Dumper;
BEGIN {plan tests => 8};

use Finance::Quote;

# Test Yahoo_europe functions.

my $q      = Finance::Quote->new();

my %quotes = $q->nzx("TPW","BOGUS");
ok(%quotes);

# Check the nav values are defined.  These are the most
#  used and most reliable indicators of success.
ok($quotes{"TPW","price"} > 0);
ok(length($quotes{"TPW","name"}) > 0);
ok($quotes{"TPW","success"});
ok($quotes{"TPW", "currency"} eq "NZD");

my $year = (localtime())[5] + 1900;
ok(substr($quotes{"TPW","isodate"},0,4) == $year);
ok(substr($quotes{"TPW","date"},6,4) == $year);

# Check that a bogus stock returns no-success.
ok(! $quotes{"BOGUS","success"});
