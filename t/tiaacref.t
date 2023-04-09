#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;
use Time::Piece;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 91;

# Test TIAA-CREF functions.

my $q      = Finance::Quote->new();
my $year   = localtime()->year;
my $lastyear = $year - 1;

my @symbols = do { no warnings 'qw'; qw/
    QCBMIX
    TEMLX
    TLFIX
    TSBPX
    W156#
    W323#
    W464#
    W719#
/};

ok( my %quotes = $q->tiaacref( @symbols, 'BOGUS' ), 'retrieved quotes' );

for my $symbol (@symbols) {

    # the following labels are expected to be supplied:
    # symbol, nav, currency, method, exchange, price, date, isodate

    ok( $quotes{$symbol,"success"} > 0,          "$symbol got retrieved"         );
    ok( $quotes{$symbol,"symbol"} eq $symbol,    "$symbol has matching symbol"   );
    ok( $quotes{$symbol,"nav"} > 0,              "$symbol has a NAV"             );
    ok( $quotes{$symbol,"nav"} =~ /^[\d\.]+$/,   "$symbol NAV looks numeric"     );
    ok( $quotes{$symbol,"currency"} eq "USD",    "$symbol currency is valid"     );
    ok( $quotes{$symbol,"method"} eq 'tiaacref', "$symbol has matching method"   );
    ok( $quotes{$symbol,"exchange"} eq 'TIAA',   "$symbol has matching exchange" );
    ok( length $quotes{$symbol,"name"},          "$symbol has defined name"      );
    ok( $quotes{$symbol,"price"} == $quotes{$symbol,'nav'},
        "$symbol price == NAV" );
    ok( substr($quotes{$symbol,"isodate"}, 0, 4) == $year
     || substr($quotes{$symbol,"isodate"}, 0, 4) == $lastyear,
        "$symbol isodate is recent" );
    ok( substr($quotes{$symbol,"date"}, 6, 4) == $year
     || substr($quotes{$symbol,"date"}, 6, 4) == $lastyear,
        "$symbol date is recent" );
};

ok( $quotes{"BOGUS","success"} == 0,    "BOGUS failed" );
ok( length $quotes{"BOGUS","errormsg"}, "BOGUS returned error message" );
