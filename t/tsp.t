#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

my $year = (localtime())[5] + 1900;
my $lastyear = $year - 1;
my $quoter = Finance::Quote->new();

my @symbols =  qw/C F G I S L2025 L2030 L2035 L2040 L2045 L2050 L2055 L2060 L2065 LINCOME/;

plan tests => 12*(1+$#symbols)+3;

my %quotes = $quoter->tsp( @symbols, "BOGUS" );
ok(%quotes);

foreach my $symbol (@symbols) {
    ok($quotes{$symbol, "success" }, "$symbol success");
    ok(substr($quotes{$symbol, "isodate"}, 0, 4) == $year
       || substr($quotes{$symbol, "isodate"}, 0, 4) == $lastyear);
    ok(substr($quotes{$symbol, "date"}, 6, 4) == $year
       || substr($quotes{$symbol, "date"}, 6, 4) == $lastyear);
    ok($quotes{$symbol,"last"} > 0);
    ok($quotes{$symbol,"currency"});
    ok(!defined($quotes{"c","exchange"}) );
}

ok( !$quotes{"BOGUS","success"});

%quotes = $quoter->fetch("tsp", @symbols);
ok(%quotes);

foreach my $symbol (@symbols) {
    ok($quotes{$symbol, "success" }, "$symbol success");
    ok(substr($quotes{$symbol, "isodate"}, 0, 4) == $year
       || substr($quotes{$symbol, "isodate"}, 0, 4) == $lastyear);
    ok(substr($quotes{$symbol, "date"}, 6, 4) == $year
       || substr($quotes{$symbol, "date"}, 6, 4) == $lastyear);
    ok($quotes{$symbol,"last"} > 0);
    ok($quotes{$symbol,"currency"});
    ok(!defined($quotes{"c","exchange"}) );
}

