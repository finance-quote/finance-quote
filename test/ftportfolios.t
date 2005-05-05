#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 10};

use Finance::Quote;

# Test FTPortfolios functions.

my $q      = Finance::Quote->new();
my $year   = (localtime())[5] + 1900;

my %quotes = $q->ftportfolios("FKYMRX");
ok(%quotes);

# Check that last and date are defined as our tests.
ok($quotes{"FKYMRX","pop"} > 0);
ok($quotes{"FKYMRX","nav"} > 0);
ok($quotes{"FKYMRX","price"} > 0);
ok($quotes{"FKYMRX","success"});
ok($quotes{"FKYMRX","currency"} eq "USD");
ok(length($quotes{"FKYMRX","date"}) > 0);
ok(substr($quotes{"FKYMRX","isodate"},0,4) == $year);
ok(substr($quotes{"FKYMRX","date"},6,4) == $year);


# Check that a bogus fund returns no-success.
%quotes = $q->ftportfolios("BOGUS");
ok( ! $quotes{"BOGUS","success"});
