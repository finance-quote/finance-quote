#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if ( not $ENV{"ONLINE_TEST"} ) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

my $q        = Finance::Quote->new('TreasuryDirect');
my $year     = ( localtime() )[5] + 1900;
my $lastyear = $year - 1;

my @symbols = qw/
    912810QT8
    912810QY7
/;

plan tests => 1 + 9*(1+$#symbols) + 3;

my %quotes = $q->treasurydirect( @symbols, "BOGUS" );
ok(%quotes);

foreach my $symbol (@symbols) {
    ok( $quotes{ $symbol, "success" }, "$symbol success" );
    ok( $quotes{ $symbol, "symbol" } eq $symbol , "$symbol defined" );
    ok( $quotes{ $symbol, "bid" } > 0, "$symbol returned bid" );
    ok( $quotes{ $symbol, "ask" } > 0, "$symbol returned ask" );
    ok( $quotes{ $symbol, "price" } > 0, "$symbol returned price" );
    ok( $quotes{ $symbol, "rate" } =~ /^\d+\.\d+%$/, "$symbol returned rate" );
    ok( $quotes{ $symbol, "isodate" } =~ /^\d{4}-\d{2}-\d{2}$/, "$symbol returned isodate" );
    ok(    substr( $quotes{ $symbol, "isodate" }, 0, 4 ) == $year
               || substr( $quotes{ $symbol, "isodate" }, 0, 4 ) == $lastyear );
    ok(    substr( $quotes{ $symbol, "date" }, 6, 4 ) == $year
               || substr( $quotes{ $symbol, "date" }, 6, 4 ) == $lastyear );
}

is( $quotes{ "912810QT8", "currency" }, 'USD' );
is( $quotes{ "912810QY7", "currency" }, 'USD' );

ok( !$quotes{ "BOGUS", "success" } );
