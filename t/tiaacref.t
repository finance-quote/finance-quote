#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 7};

use Finance::Quote;

# Test TIAA-CREF functions.

my $q      = Finance::Quote->new();

my %quotes = $q->tiaacref("CREFmony","TIAAreal","BOGOname");
ok(defined(%quotes));

ok($quotes{"CREFmony","nav"} > 0);
ok(length($quotes{"CREFmony","date"}) > 0);
ok($quotes{"TIAAreal","nav"} > 0);
ok(length($quotes{"TIAAreal","date"}) > 0);
ok($quotes{"BOGOname","success"} == 0);
ok($quotes{"BOGOname","errormsg"} eq "Bad symbol");

