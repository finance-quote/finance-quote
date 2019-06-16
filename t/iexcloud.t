#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if ( not $ENV{"ONLINE_TEST"} ) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

if ( not $ENV{"IEXCLOUD_API_KEY"} ) {
    plan skip_all => 'Set $ENV{"IEXCLOUD_API_KEY"} to run this test';
}

my $q        = Finance::Quote->new();
my $year     = (localtime())[5] + 1900;
my $lastyear = $year - 1;

# 10 NASDAQ stocks
#  4 NYSE stocks
#  1 IEX stock
my @symbols =  qw/MSFT AMZN AAPL GOOGL GOOG FB CSCO INTC CMCSA PEP BRK.A SEB NVR BKNG IBKR/;

plan tests => 10*(1+$#symbols)+2;

my %quotes = $q->iexcloud( @symbols, "BOGUS" );
ok(%quotes);

foreach my $symbol (@symbols) {
    ok( $quotes{ $symbol, "success" }, "$symbol success" );
    ok( $quotes{ $symbol, "symbol" } eq $symbol , "$symbol defined" );
    ok( $quotes{ $symbol, "open" } > 0, "$symbol returned open" );
    ok( $quotes{ $symbol, "close" } > 0, "$symbol returned close" );
    ok( $quotes{ $symbol, "last" } > 0, "$symbol returned last" );
    ok( $quotes{ $symbol, "high" } > 0, "$symbol returned high" );
    ok( $quotes{ $symbol, "low" } > 0, "$symbol returned low" );
    ok( $quotes{ $symbol, "volume" } >= 0, "$symbol returned volume" );
    ok( substr( $quotes{ $symbol, "isodate" }, 0, 4 ) == $year
        || substr( $quotes{ $symbol, "isodate" }, 0, 4 ) == $lastyear );
    ok( substr( $quotes{ $symbol, "date" }, 6, 4 ) == $year
        || substr( $quotes{ $symbol, "date" }, 6, 4 ) == $lastyear );
}

ok( !$quotes{ "BOGUS", "success" } );
