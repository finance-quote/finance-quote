#!/usr/bin/perl -w

# A test script to check for working of the YahooJSON module.

use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 43;

my $q = Finance::Quote->new();

#List of stocks to fetch. Feel free to change this during testing
my @stocks =
    ( "SUZLON.BO", "RECLTD.NS", "AMZN", "SOLB.BR", "^DJI", "BEL20.BR" );

my %quotes = $q->fetch( "yahoo_json", @stocks );
ok( %quotes, "Data returned" );

foreach my $stock (@stocks) {

    my $name = $quotes{ $stock, "name" };
    ok( $quotes{ $stock, "success" }, "Retrieved $stock" );
    if ( !$quotes{ $stock, "success" } ) {
        my $errmsg = $quotes{ $stock, "errormsg" };
        warn "Error Message:\n$errmsg\n";
    }
    else {
        ok( $name, "Name is defined : $name" );
        my $exchange = $quotes{ $stock, "exchange" };
        ok( $exchange eq 'Sourced from Yahoo Finance (as JSON)',
            "correctly retrieved through YahooJSON" );

        my $fetch_method = $quotes{ $stock, "method" };
        ok( $fetch_method eq 'yahoo_json', "fetch_method is yahoo_json" );

        my $last = $quotes{ $stock, "last" };
        ok( $last > 0, "Last $last > 0" );

        my $volume = $quotes{ $stock, "volume" };
        ok( $volume > 0, "Volume $volume > 0" ) if ( $stock ne "BEL20.BR" );

        my $type = $quotes{ $stock, "type" };
        ok( $type, "Symbol type $type" );

        #TODO: Add a test to raise a warning if the quote is excessively old
        my $isodate = $quotes{ $stock, "isodate" };

        # print "ISOdate: $isodate ";
        my $date = $quotes{ $stock, "date" };

        # print "Date: $date ";
    }
}

# Check that a bogus stock returns no-success.
%quotes = $q->fetch( "yahoo_json", "BOGUS" );
ok( !$quotes{ "BOGUS", "success" }, "BOGUS failed" );
