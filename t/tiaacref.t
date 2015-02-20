#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 45;

# Test TIAA-CREF functions.

my $q      = Finance::Quote->new();
my $year   = (localtime())[5] + 1900;
my $lastyear = $year - 1;

my @symbols = qw / CREFmony TIAAreal TLSRX TCMVX TLGRX CREFbond /;
my %quotes = $q->tiaacref(@symbols,"BOGOname");
ok(%quotes,"quotes got retrieved");

foreach my $symbol (@symbols) {
    ok($quotes{$symbol,"success"} > 0,"$symbol got retrieved");
    ok($quotes{$symbol,"nav"} > 0,"$symbol has a nav");
    ok($quotes{$symbol, "currency"} eq "USD","$symbol currency is valid");
    ok($quotes{$symbol,"price"} > 0,"$symbol price (".$quotes{$symbol,"price"}.")> 0");
    ok(length($quotes{$symbol,"date"}) > 0,"$symbol has a valid date : ".$quotes{$symbol,"date"});
    ok(substr($quotes{$symbol,"isodate"},0,4) == $year ||
           substr($quotes{$symbol,"isodate"},0,4) == $lastyear,"$symbol isodate is recent");
    ok(substr($quotes{$symbol,"date"},6,4) == $year ||
           substr($quotes{$symbol,"date"},6,4) == $lastyear,"$symbol date is recent");
};

ok($quotes{"BOGOname","success"} == 0,"BOGUS failed");
ok($quotes{"BOGOname","errormsg"} eq "Bad symbol","BOGUS returned errornsg");
