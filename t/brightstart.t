#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if ( not $ENV{"ONLINE_TEST"} ) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

my $q        = Finance::Quote->new('BrightStart');
my $year     = ( localtime() )[5] + 1900;
my $lastyear = $year - 1;

# Symbols are portfolio names. The static allocation portfolios have been in
# the lineup longest, so they are the safest test cases; the current list is
# at https://brightstart.com/investment/price-performance/ and any name in it
# will do. A plan that reshuffles its lineup can retire a portfolio, in which
# case pick another name from that page.
my @symbols = (
    'Equity Portfolio',
    'Vanguard Total Stock Market Index 529 Portfolio',
);

plan tests => 1 + 9*(1+$#symbols) + 4;

# One request covers the lot: the two portfolios, a name that cannot match, a
# name matching several portfolios, and the same portfolio without its trailing
# "Portfolio".
my $short     = 'Vanguard Total Stock Market Index 529';
my $ambiguous = 'aggressive';
my %quotes = $q->brightstart( @symbols, "BOGUS", $ambiguous, $short );
ok(%quotes);

foreach my $symbol (@symbols) {
    ok( $quotes{ $symbol, "success" }, "$symbol success" );
    ok( $quotes{ $symbol, "symbol" } eq $symbol, "$symbol defined" );
    ok( $quotes{ $symbol, "last" } > 0, "$symbol returned last" );
    ok( $quotes{ $symbol, "nav" } == $quotes{ $symbol, "last" }, "$symbol nav matches last" );
    ok( $quotes{ $symbol, "price" } == $quotes{ $symbol, "last" }, "$symbol price matches last" );
    ok( length $quotes{ $symbol, "name" }, "$symbol returned name" );
    is( $quotes{ $symbol, "currency" }, 'USD', "$symbol returned currency" );
    ok( $quotes{ $symbol, "isodate" } =~ /^\d{4}-\d{2}-\d{2}$/, "$symbol returned isodate" );
    ok(    substr( $quotes{ $symbol, "isodate" }, 0, 4 ) == $year
               || substr( $quotes{ $symbol, "isodate" }, 0, 4 ) == $lastyear );
}

ok( !$quotes{ "BOGUS", "success" }, "bogus symbol fails" );

# A name matching more than one portfolio must fail rather than pick one.
ok( !$quotes{ $ambiguous, "success" },
    "an ambiguous partial name does not resolve" );

# A portfolio named without its trailing "Portfolio" resolves to the same fund.
ok( $quotes{ $short, "success" }, "$short success" );
is( $quotes{ $short, "last" },
    $quotes{ 'Vanguard Total Stock Market Index 529 Portfolio', "last" },
    "$short resolves to the same unit value" );
