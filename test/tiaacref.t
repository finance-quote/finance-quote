#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 23};

use Finance::Quote;

# Test TIAA-CREF functions.

my $q      = Finance::Quote->new();
my $year   = (localtime())[5] + 1900;

my %quotes = $q->tiaacref("CREFmony","TIAAreal","TLSIX","TCMVX","TLGIX","BOGOname");
ok(%quotes);

ok($quotes{"CREFmony","nav"} > 0);
ok($quotes{"CREFmony", "currency"} eq "USD");
ok(length($quotes{"CREFmony","date"}) > 0);
ok(substr($quotes{"CREFmony","isodate"},0,4) == $year);
ok(substr($quotes{"CREFmony","date"},6,4) == $year);

ok($quotes{"TIAAreal","nav"} > 0);
ok(length($quotes{"TIAAreal","date"}) > 0);
ok(substr($quotes{"TIAAreal","isodate"},0,4) == $year);
ok(substr($quotes{"TIAAreal","date"},6,4) == $year);

ok($quotes{"TLSIX","success"} > 0);
ok($quotes{"TLSIX","nav"} > 0); 
ok(length($quotes{"TLSIX","date"}) > 0);
ok(substr($quotes{"TLSIX","isodate"},0,4) == $year);
ok(substr($quotes{"TLSIX","date"},6,4) == $year);

ok($quotes{"TCMVX","success"} > 0);
ok($quotes{"TCMVX","nav"} > 0); 
ok(length($quotes{"TCMVX","date"}) > 0);
ok(substr($quotes{"TCMVX","isodate"},0,4) == $year);
ok(substr($quotes{"TCMVX","date"},6,4) == $year);

ok($quotes{"TLGIX","success"} > 0);

ok($quotes{"BOGOname","success"} == 0);
ok($quotes{"BOGOname","errormsg"} eq "Bad symbol");

