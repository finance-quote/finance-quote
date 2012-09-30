#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 27;

# Test TIAA-CREF functions.

my $q      = Finance::Quote->new();
my $year   = (localtime())[5] + 1900;
my $lastyear = $year - 1;

my %quotes = $q->tiaacref("CREFmony","TIAAreal","TLSRX","TCMVX","TLGRX","BOGOname","CREFbond");
ok(%quotes);

ok($quotes{"CREFmony","nav"} > 0);
ok($quotes{"CREFmony", "currency"} eq "USD");
ok(length($quotes{"CREFmony","date"}) > 0);
ok(substr($quotes{"CREFmony","isodate"},0,4) == $year ||
   substr($quotes{"CREFmony","isodate"},0,4) == $lastyear);
ok(substr($quotes{"CREFmony","date"},6,4) == $year ||
   substr($quotes{"CREFmony","date"},6,4) == $lastyear);

ok($quotes{"TIAAreal","nav"} > 0);
ok(length($quotes{"TIAAreal","date"}) > 0);
ok(substr($quotes{"TIAAreal","isodate"},0,4) == $year ||
   substr($quotes{"TIAAreal","isodate"},0,4) == $lastyear);
ok(substr($quotes{"TIAAreal","date"},6,4) == $year ||
   substr($quotes{"TIAAreal","date"},6,4) == $lastyear);

ok($quotes{"TLSRX","success"} > 0);
ok($quotes{"TLSRX","nav"} > 0);
ok(length($quotes{"TLSRX","date"}) > 0);
ok(substr($quotes{"TLSRX","isodate"},0,4) == $year ||
   substr($quotes{"TLSRX","isodate"},0,4) == $lastyear);
ok(substr($quotes{"TLSRX","date"},6,4) == $year ||
   substr($quotes{"TLSRX","date"},6,4) == $lastyear);

ok($quotes{"TCMVX","success"} > 0);
ok($quotes{"TCMVX","nav"} > 0);
ok(length($quotes{"TCMVX","date"}) > 0);
ok(substr($quotes{"TCMVX","isodate"},0,4) == $year ||
   substr($quotes{"TCMVX","isodate"},0,4) == $lastyear);
ok(substr($quotes{"TCMVX","date"},6,4) == $year ||
   substr($quotes{"TCMVX","date"},6,4) == $lastyear);

ok($quotes{"TLGRX","success"} > 0);

ok($quotes{"BOGOname","success"} == 0);
ok($quotes{"BOGOname","errormsg"} eq "Bad symbol");

ok($quotes{"CREFbond","success"} > 0);
ok($quotes{"CREFbond","nav"} > 0);
ok($quotes{"CREFbond", "currency"} eq "USD");
ok(substr($quotes{"CREFbond","date"},6,4) == $year ||
   substr($quotes{"CREFbond","date"},6,4) == $lastyear);
