#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 10};

use Finance::Quote;

# Test ASX functions.

my $q      = Finance::Quote->new();

my %quotes = $q->asx("CML","BHP");
ok(defined(%quotes));

# Check the last values are defined.  These are the most used and most
# reliable indicators of success.
ok($quotes{"CML","last"} > 0);
ok($quotes{"CML","success"});
ok($quotes{"BHP","last"} > 0);
ok($quotes{"BHP","success"});

# Exercise the fetch function a little.
%quotes = $q->fetch("asx","ITE");
ok(defined(%quotes));
ok($quotes{"ITE","last"} > 0);
ok($quotes{"ITE","success"} > 0);

# Check that we're getting currency information.
ok($quotes{"ITE", "currency"} eq "AUD");

# Check that looking up a bogus stock returns failure:
%quotes = $q->asx("BOGUS");
ok(! $quotes{"BOGUS","success"});

