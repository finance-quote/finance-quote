#!/usr/bin/perl -w
use strict;
use Test;
use Data::Dumper;
BEGIN {plan tests => 6};

use Finance::Quote;

# Test ManInvestments functions.

my $q      = Finance::Quote->new();

my %quotes = $q->maninv("OMIP220","BOGUS");
ok(%quotes);

# Check the nav values are defined.  These are the most
#  used and most reliable indicators of success.
ok($quotes{"OMIP220","last"} > 0);
ok(length($quotes{"OMIP220","name"}) > 0);
ok($quotes{"OMIP220","success"});
ok($quotes{"OMIP220", "currency"} eq "AUD");

# Check that a bogus stock returns no-success.
ok(! $quotes{"BOGUS","success"});
