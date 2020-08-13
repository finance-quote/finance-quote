#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;
use Scalar::Util qw(looks_like_number);

if ( not $ENV{ONLINE_TEST} ) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 133;

my $q = Finance::Quote->new();

# Bourso tests need to cover all the possible cases:
#
#    Name		What		Test Case
#
#    action	        Stock		1rPAF, MSFT, FF11-SOLB, 1rPSOLB, 1rPCNP
#    obligation	        Bond		1rPFR0010371401
#    opcvm	        Fund		MP-802941
#    warrant	        Warrant		1rAHX70B - expired & removed from tests
#    indice	        Index		1rPCAC
#    tracker            Tracker         1rTBX4

my %stocks = ( "MP-802941" => "EUR",       # Fund, EUR, Covéa Actions Asie C
               "1rPAF" => "EUR",           # Stock, EUR, Euronext Paris, AIR FRANCE - KLM
               "MSFT" => "USD",            # Stock, USD, NASDAQ, MICROSOFT
               "FF11-SOLB" => "EUR",       # Stock, EUR, Euronext Bruxelles, SOLVAY
               "1rPSOLB" => "EUR",         # Stock, EUR, Euronext Paris, SOLVAY
               "1rPCNP" => "EUR",          # Stock, EUR, Euronext Paris, CNP ASSURANCES
               "2rPDE000CX0QLH6" => "EUR", # Warrant
               "1rPFR0010371401" => "%",   # Bond, EUR, Euronext Paris, FRENCH REPUBLIC 4% 25/10/38 EUR
               "1rPCAC" => "Pts",          # Index, Pts, Paris, CAC40
               "1rTBX4" => "EUR",          # Tracker, EUR, LYXOR ETF BX4
);

my $year = ( localtime() )[5] + 1900;

foreach my $stock (keys %stocks) {
    eval {
        my %quotes = $q->fetch( "bourso", $stock );
        ok(%quotes, "$stock \%quotes defined" );
        ok(length $quotes{$stock, "name"} > 0, "$stock name length > 0");
        ok($quotes{$stock, "last"} > 0, "$stock last > 0");
        ok(length $quotes{$stock, "symbol"} > 0, "$stock symbol length > 0");
        ok(length $quotes{$stock, "date"} > 0, "$stock date length > 0");
      
        my $quote_year = substr($quotes{$stock, "isodate"}, 0, 4 );
        ok ($quote_year == $year || $quote_year - 1 == $year, "$stock isodate year check");
        
        ok($quotes{$stock, "method"} eq "bourso", "$stock method is bourso");
        ok($quotes{$stock, "currency"} eq $stocks{$stock}, "$stock currency as expected");
        
        if (exists $quotes{$stock, "high"}) {
            ok(length $quotes{$stock, "exchange"}, "$stock exchange length > 0");
            ok($quotes{$stock, "high"} > 0, "$stock high > 0");
            ok($quotes{$stock, "low"} > 0, "$stock low > 0");
            ok($quotes{$stock, "close"} > 0, "$stock close > 0");
            ok(looks_like_number($quotes{$stock, "net"}), "$stock net looks like a number");
            ok(!exists $quotes{$stock, "volume"} or looks_like_number($quotes{$stock, "volume"}), "$stock volume looks like a number");
        }
        ok( $quotes{ $stock, "success" }, "$stock returned success" );
    };
    if ($@) {
        print STDERR "Error fetching stock ", $stock, "\n", $@;
        ok(!1);
    }
}

# Check that a bogus stock returns no-success.
my %quotes = $q->fetch("bourso", "BOGUS");
ok(!$quotes{ "BOGUS", "success" }, "BOGUS failed correctly");
