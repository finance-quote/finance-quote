#!/usr/bin/perl -w
use strict;
use Test;
use Data::Dumper;
BEGIN {plan tests => 6};

use Finance::Quote;

# Test Yahoo_europe functions.

my $q      = Finance::Quote->new();

my %quotes = $q->seb_funds("SEB Cancerfonden","BOGUS");
ok(%quotes);

# Check the nav values are defined.  These are the most
#  used and most reliable indicators of success.
ok($quotes{"SEB Cancerfonden","price"} > 0);
ok(length($quotes{"SEB Cancerfonden","name"}) > 0);
ok($quotes{"SEB Cancerfonden","success"});
ok($quotes{"SEB Cancerfonden", "currency"} eq "SEK");

# Check that a bogus stock returns no-success.
ok(! $quotes{"BOGUS","success"});
