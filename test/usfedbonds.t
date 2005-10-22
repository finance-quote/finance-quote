#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 15};

use Finance::Quote;

# Test usfedbonds functions.

my $q      = Finance::Quote->new("USFedBonds");

#my %quotes = $q->usfedbonds("E197001.200506");
my %quotes = $q->usfedbonds("E197001.200506","E194112.200510","E194101.200510","E194001.200510","BOGUS");
ok(%quotes);

# Check that the last and date values are defined.
ok($quotes{"E197001.200506","success"});
ok($quotes{"E197001.200506","price"} > 0);
ok(length($quotes{"E197001.200506","date"}) > 0);
ok($quotes{"E197001.200506","currency"} eq "USD");

ok($quotes{"E194112.200510","success"});
ok($quotes{"E194112.200510","price"} > 0);
ok(length($quotes{"E194112.200510","date"}) > 0);
ok($quotes{"E194112.200510","currency"} eq "USD");

# Check that a non-existent price returns no-success.
ok($quotes{"E194101.200510","success"} == 0);
ok($quotes{"E194101.200510","errormsg"} eq "No value found");

# Check that a non-existent price returns no-success.
ok($quotes{"E194001.200510","success"} == 0);
ok($quotes{"E194001.200510","errormsg"} eq "Date not found");

# Check that a bogus fund returns no-success.
ok($quotes{"BOGUS","success"} == 0);
ok($quotes{"BOGUS","errormsg"} eq "Parse error");
