#!/usr/bin/perl -w

# A test script to check for working of the XETRA module.

use strict;
use Test::More;
use Finance::Quote;
use Data::Dumper;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 76;
my $q = Finance::Quote->new();

sub test_stock_success {
    # arguments:
    #   $_[0]: isin
    #   $_[1]: exchange (starting with '.') or empty string

    my $stock = $_[0] . $_[1];
    my %quotes = $q->fetch( "xetra", $stock );

    ok( %quotes, "Data returned" );
    ok( $quotes{ $stock, "success" } == 1, "successful" );
    ok( $quotes{ $stock, "symbol" } eq $_[0], "symbol matches" );
    ok( $quotes{ $stock, "currency" } eq "EUR", "currency is euro" );
    ok( $quotes{ $stock, "method" } eq "xetra", "method is correct" );

    my $exchange = $_[1] eq "" ? "XETR" : substr($_[1], 1);
    ok( $quotes{ $stock, "exchange" } eq $exchange, "exchange is correct" );

    my @fields = ( "close", "high", "low", "last", "date", "isodate" );
    foreach my $field (@fields) {
        ok( $quotes { $stock, $field }, $field . " is defined");
    }
}

my @stocks = ( "IE0031442068", "IE00B4L5YC18" );
foreach my $stock (@stocks) {
    test_stock_success( $stock, ".XFRA" );
    test_stock_success( $stock, ".XETR" );
    test_stock_success( $stock, "" );
}

my %qu1 = $q->fetch( "xetra", "ABC.DEF.GHI" );
ok( $qu1{ "ABC.DEF.GHI", "success" } == 0, "wrong format fails" );
ok( index( $qu1{ "ABC.DEF.GHI", "errormsg" }, "Invalid format" )  != -1, "descriptive error message" );

my %qu2 = $q->fetch( "xetra", "notfound" );
ok( $qu2{ "notfound", "success" } == 0, "not existing fails" );
ok( index( $qu2{ "notfound", "errormsg" }, "HTTP response 400" )  != -1, "http code 400" );

