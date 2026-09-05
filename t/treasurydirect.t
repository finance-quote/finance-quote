#!/usr/bin/perl -w
use strict;
use Test::More;
use Scalar::Util qw(looks_like_number);
use Finance::Quote;

if ( not $ENV{"ONLINE_TEST"} ) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

my $q        = Finance::Quote->new('TreasuryDirect');
my $year     = ( localtime() )[5] + 1900;
my $lastyear = $year - 1;

# Long dated bonds, chosen so this test does not need updating often, and
# quoted on both sides so bid and ask are both present. Any CUSIP
# in the FedInvest daily price file works; the file for a given business day is
# reachable from
# https://www.treasurydirect.gov/GA-FI/FedInvest/selectSecurityPriceDate.htm
# Only marketable Treasuries are listed there - agency, municipal and corporate
# CUSIPs are not, and return 'no match'.
my @symbols = qw/
    912810QT8
    912810QY7
/;

plan tests => 1 + 12*(1+$#symbols) + 3;

my %quotes = $q->treasurydirect( @symbols, "BOGUS" );
ok(%quotes);

foreach my $symbol (@symbols) {
    ok( $quotes{ $symbol, "success" }, "$symbol success" );
    ok( $quotes{ $symbol, "symbol" } eq $symbol , "$symbol defined" );

    ok( looks_like_number( $quotes{ $symbol, "bid" } )
            && $quotes{ $symbol, "bid" } > 0, "$symbol returned bid" );
    ok( looks_like_number( $quotes{ $symbol, "ask" } )
            && $quotes{ $symbol, "ask" } > 0, "$symbol returned ask" );
    ok( looks_like_number( $quotes{ $symbol, "price" } )
            && $quotes{ $symbol, "price" } > 0, "$symbol returned price" );

    # FedInvest's SELL is what an investor receives and BUY is what they pay,
    # so reading the two columns the wrong way round shows up here as a
    # negative spread.
    ok( $quotes{ $symbol, "ask" } >= $quotes{ $symbol, "bid" },
        "$symbol ask is not below bid" );

    # Averaging a quoted price against an unquoted zero halves it. Both of
    # these are quoted on both sides, so the mean sits between them.
    ok( $quotes{ $symbol, "price" } > 0.9 * $quotes{ $symbol, "bid" },
        "$symbol price is not a halved average" );

    ok( $quotes{ $symbol, "rate" } =~ /^\d+\.\d+%$/, "$symbol returned rate" );
    ok( $quotes{ $symbol, "maturity" } =~ m{^\d{2}/\d{2}/\d{4}$},
        "$symbol returned maturity" );
    ok( $quotes{ $symbol, "isodate" } =~ /^\d{4}-\d{2}-\d{2}$/, "$symbol returned isodate" );
    ok(    substr( $quotes{ $symbol, "isodate" }, 0, 4 ) == $year
               || substr( $quotes{ $symbol, "isodate" }, 0, 4 ) == $lastyear );
    ok(    substr( $quotes{ $symbol, "date" }, 6, 4 ) == $year
               || substr( $quotes{ $symbol, "date" }, 6, 4 ) == $lastyear );
}

is( $quotes{ "912810QT8", "currency" }, 'USD' );
is( $quotes{ "912810QY7", "currency" }, 'USD' );

ok( !$quotes{ "BOGUS", "success" } );
