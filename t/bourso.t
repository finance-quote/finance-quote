#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if ( not $ENV{ONLINE_TEST} ) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 71;

# Test Bourso functions.

my $q = Finance::Quote->new();

# my stocks = stock, fund, warrant, bond, indice, tracker
my %stocks = ( "MP-802941" => "FR0000441677",       # Fund, EUR, Covéa Actions Asie C
               "1rPAF" => "FR0000031122",           # Stock, EUR, Euronext Paris, AIR FRANCE - KLM
               "MSFT" => "US5949181045",            # Stock, USD, NASDAQ, MICROSOFT
               "FF11-SOLB" => "BE0003470755",       # Stock, EUR, Euronext Bruxelles, SOLVAY
               "1rPSOLB" => "BE0003470755",         # Stock, EUR, Euronext Paris, SOLVAY
               "1rPCNP" => "FR0000120222",          # Stock, EUR, Euronext Paris, CNP ASSURANCES
               "1rPFR0010371401" => "FR0010371401", # Bond, EUR, Euronext Paris, FRENCH REPUBLIC 4% 25/10/38 EUR
               "1rAHX70B" => "NL0011806336",        # Warrant, EUR, Euronext Paris, SAMSUNG ELEC/BNP WT
               "1rPCAC" => "FR0003500008",          # Index, Pts, Paris, CAC40
               "1rTBX4" => "FR0010411884",          # Tracker, EUR, LYXOR ETF BX4
);

# Bourso tests need to cover all the possible cases:
#
#    Name		What		Test Case
#
#    action	        Stock		1rPAF, MSFT, FF11-SOLB, 1rPSOLB, 1rPCNP
#    obligation	        Bond		1rPFR0010371401
#    opcvm	        Fund		MP-802941
#    warrant	        Warrant		1rAHX70B
#    indice	        Index		1rPCAC
#    tracker            Tracker         1rTBX4

my $year     = ( localtime() )[5] + 1900;
my $lastyear = $year - 1;

my %quotes;

#my %quotes = $q->fetch("bourso", @stocks);
#ok(%quotes);

# Check that the name, last, currency and date are defined for all of the stocks.
foreach my $stock (keys %stocks) {
    eval {
        %quotes = $q->fetch( "bourso", $stock );
        ok( %quotes, "$stock \%quotes defined" );

        my $last = $quotes{ $stock, "last" };
        ok( $last > 0, "$stock last ($last) > 0" );
        ok( length( $quotes{ $stock, "name" } ),   "$stock name is defined" );
        ok( $quotes{ $stock, "success" }, "$stock returned success" );
        ok(    # bonds are quoted in percents and index in points
            ( $stock eq "1rPFR0010371401" ) || ( $stock eq "1rPCAC" ) 
                || (    ( $stock eq "MSFT" )
                     && ( $quotes{ $stock, "currency" } eq "USD" ) )
                || ( $quotes{ $stock, "currency" } eq "EUR" ),
            "Currency as expected"
        );

    SKIP:
        {
            ok( substr( $quotes{ $stock, "isodate" }, 0, 4 ) == $year
                    || substr( $quotes{ $stock, "isodate" }, 0, 4 )
                    == $lastyear,
                "$stock isodate defined"
            );
            ok( substr( $quotes{ $stock, "date" }, 6, 4 ) == $year
                    || substr( $quotes{ $stock, "date" }, 6, 4 ) == $lastyear,
                "$stock date defined"
            );
        }
    };
    if ($@) {
        print STDERR "Error fetching stock ", $stock, "\n", $@;
        ok( !1 );
    }
}

# Check that a bogus stock returns no-success.
%quotes = $q->fetch( "bourso", "BOGUS" );
ok( !$quotes{ "BOGUS", "success" }, "BOGUS failed correctly" );
