#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 12};

use Finance::Quote;

# Test TIAA-CREF functions.

my $q      = Finance::Quote->new();

my %quotes = $q->tiaacref("CREFmony","TIAAgrin","TIAAreal","TIAAsndx","BOGOname");
ok(%quotes);

ok($quotes{"CREFmony","nav"} > 0);
ok($quotes{"CREFmony", "currency"} eq "USD");
ok(length($quotes{"CREFmony","date"}) > 0);

ok($quotes{"TIAAreal","nav"} > 0);
ok(length($quotes{"TIAAreal","date"}) > 0);

#Now check the other URL

ok($quotes{"TIAAsndx","success"} > 0);
ok ($quotes{"TIAAsndx","nav"} > 0); 
ok(length($quotes{"TIAAsndx","date"}) > 0);

ok($quotes{"TIAAgrin","success"} > 0);

ok($quotes{"BOGOname","success"} == 0);
ok($quotes{"BOGOname","errormsg"} eq "Bad symbol");

