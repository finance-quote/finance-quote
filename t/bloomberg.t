#!/usr/bin/perl

use warnings;
use strict;

use Test::More;
use Finance::Quote;

if ( not $ENV{ONLINE_TEST} ) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 15;

my $q        = Finance::Quote->new;
my $year     = ( localtime() )[5] + 1900;
my $lastyear = $year - 1;

# Test Bloomberg Stocks Index functions.

my %quotes = $q->fetch( 'bloomberg_stocks_index', 'MXEF:IND', 'BOGUS:IND' );
ok( %quotes, "bloomberg_stocks_index() returns hash" );

ok( $quotes{ 'MXEF:IND', 'source' } eq 'http://www.bloomberg.com/',
    "source should be http://www.bloomberg.com/" );
ok( $quotes{ 'MXEF:IND', 'method' } eq 'bloomberg_stocks_index',
    "method should be bloomberg_stocks_index" );

ok( $quotes{ 'MXEF:IND', 'success' }, "MXEF:IND should be success" );
ok(
    $quotes{ "MXEF:IND", "price" } > 0,
    "MXEF:IND's price should be greater than 0"
);
ok(
    $quotes{ "MXEF:IND", "open" } > 0,
    "MXEF:IND's open should be greater than 0"
);
ok(
    $quotes{ "MXEF:IND", "high" } > 0,
    "MXEF:IND's high should be greater than 0"
);
ok( $quotes{ "MXEF:IND", "low" } > 0,
    "MXEF:IND's high should be greater than 0" );
ok( $quotes{ "MXEF:IND", "net" }, "MXEF:IND's net should be defined" );
ok(
    $quotes{ "MXEF:IND", "name" } eq "MSCI Emerging Markets Index",
    "MXEF:IND's name should be 'MSCI Emerging Markets Index'"
);
ok(
    $quotes{ "MXEF:IND", "currency" } eq "USD",
    "MXEF:IND's currency should be USD"
);
ok(
    substr( $quotes{ "MXEF:IND", "isodate" }, 0, 4 ) == $year
      || substr( $quotes{ "MXEF:IND", "isodate" }, 0, 4 ) == $lastyear,
    "year of isodate should be this year or last year"
);
ok(
    substr( $quotes{ "MXEF:IND", "date" }, 6, 4 ) == $year
      || substr( $quotes{ "MXEF:IND", "date" }, 6, 4 ) == $lastyear,
    "year of isodate should be this year or last year"
);
ok(
    $quotes{ "MXEF:IND", "p_change" } !~ /%/,
    "p_change shouldn't have spurious % signs"
);

ok( !$quotes{ "BOGUS.SI", "success" },
    "BOGUS Stocks Index returns no-success" );
