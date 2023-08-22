#!/usr/bin/perl -w

# A test script to check for working of the YahooChart module.

use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 66;

my $q = Finance::Quote->new();

#List of stocks to fetch. Feel free to change this during testing
my @stocks =
    ( "SUZLON.BO", "RECLTD.NS", "AMZN", "SOLB.BR", "^DJI", "AENA.MC", "CFR.JO", "BK" );

my %quotes = $q->fetch( "yahoo_chart", @stocks );
ok( %quotes, "Data returned" );

foreach my $stock (@stocks) {

    my $symbol = $quotes{ $stock, "symbol" };
    ok( $quotes{ $stock, "success" }, "Retrieved $stock" );
    if ( !$quotes{ $stock, "success" } ) {
        my $errmsg = $quotes{ $stock, "errormsg" };
        warn "Error Message:\n$errmsg\n";
    }
    else {
	ok( $symbol, "Symbol is defined : $symbol" );
        my $exchange = $quotes{ $stock, "exchange" };
        ok( $exchange ne '',
            "correctly retrieved through YahooChart" );

        my $fetch_method = $quotes{ $stock, "method" };
        ok( $fetch_method eq 'yahoo_chart', "fetch_method is yahoo_chart" );

        my $close = defined ($quotes{ $stock, "nav" }) ? $quotes{ $stock, "nav" } : $quotes{ $stock, "close" };
        ok( $close > 0, "Close/Nav $close > 0" );

        my $type = $quotes{ $stock, "type" };
        ok( $type, "Symbol type $type" );

        my $volume = $quotes{ $stock, "volume" };
        ok( $volume > 0, "Volume $volume > 0" );

        #TODO: Add a test to raise a warning if the quote is excessively old
        my $isodate = $quotes{ $stock, "isodate" };

        # print "ISOdate: $isodate ";
        my $date = $quotes{ $stock, "date" };

        ok( $quotes { $stock, "currency" } eq 'INR', 'Bombay stocks have currency INR' ) if $stock =~ /\.BO$/ ;
        ok( $quotes { $stock, "currency" } eq 'EUR', 'Barcelona stocks have currency EUR' ) if $stock =~ /\.BC$/ ;
        ok( $quotes { $stock, "currency" } eq 'EUR', 'Madrid stocks have currency EUR' ) if $stock =~ /\.MC$/ ;
        ok( $quotes { $stock, "currency" } eq 'ZAR', 'Johannesburg stocks have currency ZAR' ) if $stock =~ /\.JO$/ ;

        # print "Date: $date ";
    }
}

# Check that a bogus stock returns no-success.
@stocks = ("BOGUS", "12345", "ITG", "BEL20.BR", "INGDIRECTFNE.BC");

%quotes = $q->fetch( "yahoo_chart", @stocks );
ok( %quotes, "Data returned" );

foreach my $stock (@stocks) {
	ok( !$quotes{ $stock, "success" }, "Error retrieving quote for" );
}
