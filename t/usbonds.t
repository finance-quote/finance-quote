#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if ( not $ENV{"ONLINE_TEST"} ) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

my $q        = Finance::Quote->new('USBonds');
my $year     = ( localtime() )[5] + 1900;
my $lastyear = $year - 1;

my @symbols = qw/
    EE-100-2020-07
    EE-50-2015-04
/;

plan tests => 1 + 6*(1+$#symbols) + 3;

my %quotes = $q->usbonds( @symbols, "BOGUS" );
ok(%quotes);

foreach my $symbol (@symbols) {
    ok( $quotes{ $symbol, "success" }, "$symbol success" );
    ok( $quotes{ $symbol, "symbol" } eq $symbol , "$symbol defined" );
    ok( $quotes{ $symbol, "price" } > 0, "$symbol returned price" );
    ok( $quotes{ $symbol, "isodate" } =~ /^\d{4}-\d{2}-\d{2}$/, "$symbol returned isodate" );
    ok(    substr( $quotes{ $symbol, "isodate" }, 0, 4 ) == $year
               || substr( $quotes{ $symbol, "isodate" }, 0, 4 ) == $lastyear );
    ok(    substr( $quotes{ $symbol, "date" }, 6, 4 ) == $year
               || substr( $quotes{ $symbol, "date" }, 6, 4 ) == $lastyear );
}

is( $quotes{ "EE-100-2020-07", "currency" }, 'USD' );
is( $quotes{ "EE-50-2015-04", "currency" }, 'USD' );

ok( !$quotes{ "BOGUS", "success" }, "symbol BOGUS fails" );
