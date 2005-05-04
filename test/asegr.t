#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 11};

use Finance::Quote;

# Test ASEGR functions.

my $q      = Finance::Quote->new();

my %quotes = $q->asegr("ALPHA","ELTON");
ok(%quotes);

# Check the last values are defined.  These are the most used and most
# reliable indicators of success.
ok($quotes{"ALPHA","last"} > 0);
ok($quotes{"ALPHA","success"});
ok($quotes{"ELTON","success"});
ok($quotes{"ELTON","last"} > 0);

# Exercise the fetch function a little.
%quotes = $q->fetch("asegr","IKONA");
ok(%quotes);
ok($quotes{"IKONA","last"} > 0);
ok($quotes{"IKONA","success"} > 0);

# Check that we're getting currency information.
ok($quotes{"IKONA", "currency"} eq "EUR");

# Check we're not getting bogus percentage signs.
$quotes{"IKONA","p_change"} ||= "";	# Avoid warning if undefined.
ok($quotes{"IKONA","p_change"} !~ /%/);

# Check that looking up a bogus stock returns failure:
%quotes = $q->asegr("BOGUS");
ok(! $quotes{"BOGUS","success"});

