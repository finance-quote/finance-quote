#!/usr/bin/perl -w
use strict;
use warnings;
use Scalar::Util qw(looks_like_number);
use Finance::Quote;
use Test::More;
use Time::Piece;
use feature "say";

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 108;

my $now = localtime;;
my $a_year_ago = $now->add_years(-1);

my @symbols = qw/
    WES
    BOQ
    XRO
    IAG
    TLS
/;
my @indices = qw/
    XAO
    NABHA
/;

# Invoke test subject
my $q = Finance::Quote->new();
ok( my %quotes = $q->asx(@symbols, @indices, 'BOGUS'), "fetch quotes" );

# Check the valid securities
for my $symbol (@symbols) {

    ok( $quotes{$symbol, 'success'} == 1,      "success for $symbol"   );
    ok( $quotes{$symbol, 'currency'} eq 'AUD', "got expected currency" );
    ok( $quotes{$symbol, 'method'} eq 'asx',   "got expected method"   );
    ok( length $quotes{$symbol,'name'},        "got a name"            );
    ok( $quotes{$symbol,'symbol'} eq $symbol,  "matching symbol"       );

    ok( $quotes{$symbol, 'exchange'} eq 'Australian Securities Exchange',
        "got expected exchange" );

    my $date = Time::Piece->strptime($quotes{$symbol,"date"}, '%m/%d/%Y');
    ok( $date >= localtime()->add_years(-1), "date recent enough" );
    my $isodate = Time::Piece->strptime($quotes{$symbol,"isodate"}, '%Y-%m-%d');
    ok( $isodate >= localtime()->add_years(-1), "isodate recent enough" );

    for my $field (qw/last price open close high low volume/) {
        ok( $quotes{$symbol, $field} > 0, "$field > 0" );
    }

    for my $field (qw/net p_change/) {
        ok( looks_like_number($quotes{$symbol, $field}),
            "$field looks like number" );
    }
}

# Check the indexes 
for my $symbol (@indices) {

    ok( $quotes{$symbol, 'success'} == 1,      "success for $symbol"   );
    ok( $quotes{$symbol, 'method'} eq 'asx',   "got expected method"   );
    ok( length $quotes{$symbol,'name'},        "got a name"            );
    ok( $quotes{$symbol,'symbol'} eq $symbol,  "matching symbol"       );

    ok( $quotes{$symbol, 'exchange'} eq 'Australian Securities Exchange',
        "got expected exchange" );

    for my $field (qw/last price volume/) {
        ok( $quotes{$symbol, $field} > 0, "$field > 0" );
    }

    for my $field (qw/net p_change/) {
        ok( looks_like_number($quotes{$symbol, $field}),
            "$field looks like number" );
    }
}
# Check that an invalid fund returns failure:
ok( !$quotes{'BOGUS', "success"},      , "bad symbol returned no result"    );
ok( $quotes{'BOGUS',  "errormsg"} ne '', "got error message for bad symbol" );
