#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 5};

use Finance::Quote;

# Test ASX functions.

my $q      = Finance::Quote->new();

my %quotes = $q->asx("CML","BHP");
ok(defined(%quotes));

# Check the last values are defined.  These are the most used and most
# reliable indicators of success.
ok($quotes{"CML","last"} > 0);
ok($quotes{"BHP","last"} > 0);

%quotes = $q->fetch("asx","ITE");
ok(defined(%quotes));
ok($quotes{"ITE","last"} > 0);
