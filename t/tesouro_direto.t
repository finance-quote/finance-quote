#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if ( not $ENV{"ONLINE_TEST"} ) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

my @bounds = ("Tesouro Prefixado 2031", "Tesouro IPCA+ 2045");

plan tests => 1 + 8*(1+$#bounds) + 1;

my $q = Finance::Quote->new();
my $year     = ( localtime() )[5] + 1900;
my $lastyear = $year - 1;

my %quotes = $q->fetch("tesouro_direto", @bounds);
ok(%quotes);

foreach my $bound (@bounds) {
    ok( $quotes{$bound, "success"}, "$bound success" );
    is( $quotes{$bound, "exchange"}, "Tesouro Direto", "$bound exchange correct" );
    is( $quotes{$bound, "name"}, $bound, "$bound name correct" );
    is( $quotes{$bound, "symbol"}, $bound, "$bound symbol correct" );
    ok( $quotes{$bound, "price"} > 0, "$bound price positive" );
    ok( $quotes{$bound, "last"} > 0, "$bound last positive" );
    is( $quotes{$bound, "method"}, "tesouro_direto", "$bound method correct" );
    is( $quotes{$bound, "currency"}, "BRL", "$bound currency correct" );
}

%quotes = $q->fetch( "tesouro_direto", "BOGUS" );
ok( !$quotes{ "BOGUS", "success" }, "BOGUS failed" );
