#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if ( not $ENV{"ONLINE_TEST"} ) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

if ( not $ENV{"WORLDTRADING_API_KEY"} ) {
    plan skip_all =>
        'Set $ENV{WORLDTRADING_API_KEY} to run this test; get one at https://www.worldtradingdata.com';
}

my $q        = Finance::Quote->new();
my $year     = ( localtime() )[5] + 1900;
my $lastyear = $year - 1;

my @symbols =  qw/ RGAGX VEXRX RTRIX/;

plan tests => 10*(1+$#symbols)+10;

my %quotes = $q->wtdfunds( @symbols, "BOGUS" );
ok(%quotes);

foreach my $symbol (@symbols) {
    ok( $quotes{ $symbol, "success" }, "$symbol success" );
    ok( $quotes{ $symbol, "symbol" } eq $symbol , "$symbol defined" );
    ok( $quotes{ $symbol, "close" } > 0, "$symbol returned close" );
    ok(    substr( $quotes{ $symbol, "isodate" }, 0, 4 ) == $year
               || substr( $quotes{ $symbol, "isodate" }, 0, 4 ) == $lastyear );
    ok(    substr( $quotes{ $symbol, "date" }, 6, 4 ) == $year
               || substr( $quotes{ $symbol, "date" }, 6, 4 ) == $lastyear );
}

is( $quotes{ "RGAGX", "currency" }, 'USD' );

ok( !$quotes{ "BOGUS", "success" } );
