#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if ( not $ENV{"ONLINE_TEST"} ) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

my @bonds = ("IT0000966017", "IT0005592370", "IT0001086567", "IT0005534984");

plan tests => 1 + 8*(1+$#bonds) + 1;

my $q = Finance::Quote->new();
my $year     = ( localtime() )[5] + 1900;
my $lastyear = $year - 1;

my %quotes = $q->fetch("borsa_italiana", @bonds);
ok(%quotes);

foreach my $bound (@bonds) {
    ok( $quotes{$bound, "success"}, "$bound success" );
    is( $quotes{$bound, "exchange"}, "Borsa Italiana", "$bound exchange correct" );
    ok( $quotes{$bound, "name"}, "$bound name correct" );
    is( $quotes{$bound, "symbol"}, $bound, "$bound symbol correct" );
    ok( $quotes{$bound, "price"} > 0, "$bound price positive" );
    ok( $quotes{$bound, "last"} > 0, "$bound last positive" );
    is( $quotes{$bound, "method"}, "borsa_italiana", "$bound method correct" );
    is( $quotes{$bound, "currency"}, "EUR", "$bound currency correct" );
}

%quotes = $q->fetch( "borsa_italiana", "BOGUS" );
ok( !$quotes{ "BOGUS", "success" }, "BOGUS failed" );
