#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 11};

use Finance::Quote;

# Test Yahoo functions.

my $q      = Finance::Quote->new();
my $year   = (localtime())[5] + 1900;

my %quotes = $q->yahoo("IBM","CSCO","BOGUS");
ok(%quotes);

# Check the last values are defined.  These are the most
#  used and most reliable indicators of success.
ok($quotes{"IBM","last"} > 0);
ok($quotes{"IBM","success"});
ok($quotes{"IBM", "currency"} eq "USD");
ok(($quotes{"IBM", "currency"} eq "USD") &&
   !defined($quotes{"IBM","currency_set_by_fq"}));
ok(substr($quotes{"IBM","isodate"},0,4) == $year);
ok(substr($quotes{"IBM","date"},6,4) == $year);

ok($quotes{"CSCO","last"} > 0);
ok($quotes{"CSCO","success"});

# Make sure there are no spurious % signs.

ok($quotes{"CSCO","p_change"} !~ /%/);

# Check that bogus stocks return failure:

ok(! $quotes{"BOGUS","success"});
