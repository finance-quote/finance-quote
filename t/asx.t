#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 3};

use Finance::Quote;

# Test ASX functions.

my $q      = Finance::Quote->new();

my %quotes = $q->asx("CML","BHP");
ok(defined(%quotes));

# Check the last values are defined.  These are the most used and most
# reliable indicators of success.
ok($quotes{"CML","last"});
ok($quotes{"BHP","last"});
