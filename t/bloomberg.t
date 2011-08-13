#!/usr/bin/perl

use warnings;
use strict;

use Test::More;
use Finance::Quote;

if ( not $ENV{ONLINE_TEST} ) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 71;

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
ok( $quotes{ "MXEF:IND", "price" } > 0,
    "MXEF:IND's price should be greater than 0"
);
ok( $quotes{ "MXEF:IND", "open" } > 0,
    "MXEF:IND's open should be greater than 0"
);
ok( $quotes{ "MXEF:IND", "high" } > 0,
    "MXEF:IND's high should be greater than 0"
);
ok( $quotes{ "MXEF:IND", "low" } > 0,
    "MXEF:IND's high should be greater than 0" );
ok( $quotes{ "MXEF:IND", "net" }, "MXEF:IND's net should be defined" );
ok( $quotes{ "MXEF:IND", "name" } eq "MSCI Emerging Markets Index",
    "MXEF:IND's name should be 'MSCI Emerging Markets Index'"
);
ok( $quotes{ "MXEF:IND", "currency" } eq "USD",
    "MXEF:IND's currency should be USD"
);
ok( substr( $quotes{ "MXEF:IND", "isodate" }, 0, 4 ) == $year
        || substr( $quotes{ "MXEF:IND", "isodate" }, 0, 4 ) == $lastyear,
    "year of isodate should be this year or last year"
);
ok( substr( $quotes{ "MXEF:IND", "date" }, 6, 4 ) == $year
        || substr( $quotes{ "MXEF:IND", "date" }, 6, 4 ) == $lastyear,
    "year of isodate should be this year or last year"
);
ok( $quotes{ "MXEF:IND", "p_change" } !~ /%/,
    "p_change shouldn't have spurious % signs"
);

ok( !$quotes{ "BOGUS.SI", "success" },
    "BOGUS Stocks Index returns no-success"
);


# Test Bloomberg ETF functions.
%quotes = $q->fetch( 'bloomberg_etf', '1681:JP', '1557:JP', 'BOGUS:JP' );
ok( %quotes, "bloomberg_etf() returns hash" );

ok( $quotes{ '1681:JP', 'source' } eq 'http://www.bloomberg.com/',
    "source should be http://www.bloomberg.com/" );
ok( $quotes{ '1681:JP', 'method' } eq 'bloomberg_etf',
    "method should be bloomberg_stocks_index"
);

ok( $quotes{ '1681:JP', 'success' }, "1681:JP should be success" );
ok( $quotes{ "1681:JP", "price" } > 0,
    "1681:JP's price should be greater than 0"
);
ok( $quotes{ "1681:JP", "open" } > 0,
    "1681:JP's open should be greater than 0"
);
ok( $quotes{ "1681:JP", "high" } > 0,
    "1681:JP's high should be greater than 0"
);
ok( $quotes{ "1681:JP", "low" } > 0,
    "1681:JP's high should be greater than 0" );
ok( $quotes{ "1681:JP", "net" }, "1681:JP's net should be defined" );
ok( $quotes{ "1681:JP", "name" } eq
        "Listed Index Fund International Emerging Countries Equity - MSCI EMERGING",
    "1681:JP's name should be 'Listed Index Fund International Emerging Countries Equity - MSCI EMERGING'"
);
ok( $quotes{ "1681:JP", "currency" } eq "JPY",
    "1681:JP's currency should be JPY"
);
ok( substr( $quotes{ "1681:JP", "isodate" }, 0, 4 ) == $year
        || substr( $quotes{ "1681:JP", "isodate" }, 0, 4 ) == $lastyear,
    "year of isodate should be this year or last year"
);
ok( substr( $quotes{ "1681:JP", "date" }, 6, 4 ) == $year
        || substr( $quotes{ "1681:JP", "date" }, 6, 4 ) == $lastyear,
    "year of isodate should be this year or last year"
);
ok( $quotes{ "1681:JP", "p_change" } !~ /%/,
    "p_change shouldn't have spurious % signs"
);
ok( $quotes{ "1681:JP", "nav" } > 0,
    "1681:JP's nav should be greater than 0"
);
ok( $quotes{ "1681:JP", "p_premium" } !~ /%/,
    "p_premium shouldn't have spurious % signs"
);

ok( $quotes{ '1681:JP', 'source' } eq 'http://www.bloomberg.com/',
    "source should be http://www.bloomberg.com/" );
ok( $quotes{ '1681:JP', 'method' } eq 'bloomberg_etf',
    "method should be bloomberg_stocks_index"
);

ok( $quotes{ '1557:JP', 'success' }, "1557:JP should be success" );
ok( $quotes{ "1557:JP", "price" } > 0,
    "1557:JP's price should be greater than 0"
);
ok( $quotes{ "1557:JP", "open" } > 0,
    "1557:JP's open should be greater than 0"
);
ok( $quotes{ "1557:JP", "high" } > 0,
    "1557:JP's high should be greater than 0"
);
ok( $quotes{ "1557:JP", "low" } > 0,
    "1557:JP's high should be greater than 0" );
ok( $quotes{ "1557:JP", "net" }, "1557:JP's net should be defined" );
ok( $quotes{ "1557:JP", "name" } eq "SPDR S&P 500 ETF Trust",
    "1557:JP's name should be 'SPDR S&P 500 ETF Trust'"
);
ok( $quotes{ "1557:JP", "currency" } eq "JPY",
    "1557:JP's currency should be JPY"
);
ok( substr( $quotes{ "1557:JP", "isodate" }, 0, 4 ) == $year
        || substr( $quotes{ "1557:JP", "isodate" }, 0, 4 ) == $lastyear,
    "year of isodate should be this year or last year"
);
ok( substr( $quotes{ "1557:JP", "date" }, 6, 4 ) == $year
        || substr( $quotes{ "1557:JP", "date" }, 6, 4 ) == $lastyear,
    "year of isodate should be this year or last year"
);
ok( $quotes{ "1557:JP", "p_change" } !~ /%/,
    "p_change shouldn't have spurious % signs"
);
ok( $quotes{ "1557:JP", "nav" } eq "N.A." || $quotes{ "1557:JP", "nav" },
    "1557:JP's nav should be greater than 0 or 'N.A.'" );
ok( $quotes{ "1557:JP", "p_premium" } !~ /%/,
    "p_premium shouldn't have spurious % signs"
);

ok( !$quotes{ "BOGUS:JP", "success" }, "BOGUS ETF returns no-success" );


# Test Bloomberg fund functions.
%quotes = $q->fetch( 'bloomberg_fund', '81317104:JP', 'BOGUS:JP' );
ok( %quotes, "bloomberg_fund() returns hash" );

ok( $quotes{ '81317104:JP', 'source' } eq 'http://www.bloomberg.com/',
    "source should be http://www.bloomberg.com/" );
ok( $quotes{ '81317104:JP', 'method' } eq 'bloomberg_fund',
    "method should be bloomberg_fund" );

ok( $quotes{ '81317104:JP', 'success' }, "81317104:JP should be success" );
ok( $quotes{ "81317104:JP", "price" } > 0,
    "81317104:JP's price should be greater than 0"
);
ok( $quotes{ "81317104:JP", "net" }, "81317104:JP's net should be defined" );
ok( $quotes{ "81317104:JP", "name" } eq "CMAM Japan Bond Index e",
    "81317104:JP's name should be 'CMAM Japan Bond Index e'"
);
ok( $quotes{ "81317104:JP", "currency" } eq "JPY",
    "81317104:JP's currency should be JPY"
);
ok( substr( $quotes{ "81317104:JP", "isodate" }, 0, 4 ) == $year
        || substr( $quotes{ "81317104:JP", "isodate" }, 0, 4 ) == $lastyear,
    "year of isodate should be this year or last year"
);
ok( substr( $quotes{ "81317104:JP", "date" }, 6, 4 ) == $year
        || substr( $quotes{ "81317104:JP", "date" }, 6, 4 ) == $lastyear,
    "year of isodate should be this year or last year"
);
ok( $quotes{ "81317104:JP", "p_change" } !~ /%/,
    "p_change shouldn't have spurious % signs"
);

ok( !$quotes{ "BOGUS:JP", "success" }, "BOGUS Fund returns no-success" );


# Test Bloomberg stock functions.
%quotes = $q->fetch( 'bloomberg_stock', '7203:JP', 'BOGUS:JP' );
ok( %quotes, "bloomberg_stock() returns hash" );

ok( $quotes{ '7203:JP', 'source' } eq 'http://www.bloomberg.com/',
    "source should be http://www.bloomberg.com/" );
ok( $quotes{ '7203:JP', 'method' } eq 'bloomberg_stock',
    "method should be bloomberg_stock" );

ok( $quotes{ '7203:JP', 'success' }, "7203:JP should be success" );
ok( $quotes{ "7203:JP", "price" } > 0,
    "7203:JP's price should be greater than 0"
);
ok( $quotes{ "7203:JP", "net" }, "7203:JP's net should be defined" );
ok( $quotes{ "7203:JP", "name" } eq "Toyota Motor Corp",
    "7203:JP's name should be 'Toyota Motor Corp'"
);
ok( $quotes{ "7203:JP", "currency" } eq "JPY",
    "7203:JP's currency should be JPY"
);
ok( substr( $quotes{ "7203:JP", "isodate" }, 0, 4 ) == $year
        || substr( $quotes{ "7203:JP", "isodate" }, 0, 4 ) == $lastyear,
    "year of isodate should be this year or last year"
);
ok( substr( $quotes{ "7203:JP", "date" }, 6, 4 ) == $year
        || substr( $quotes{ "7203:JP", "date" }, 6, 4 ) == $lastyear,
    "year of isodate should be this year or last year"
);
ok( $quotes{ "7203:JP", "p_change" } !~ /%/,
    "p_change shouldn't have spurious % signs"
);

ok( !$quotes{ "BOGUS:JP", "success" }, "BOGUS returns no-success" );
