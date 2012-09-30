#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if ( not $ENV{ONLINE_TEST} ) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 9;

# Test SIXshares functions.

my $q        = Finance::Quote->new();
my $year     = ( localtime() )[5] + 1900;
my $lastyear = $year - 1;

my %quotes = $q->sixfunds( 'CSSMI', 'BOGUS' );
ok(%quotes);

# Check the nav values are defined.  These are the most
#  used and most reliable indicators of success.
ok( $quotes{ 'CSSMI', 'last' } > 0 );
ok( length( $quotes{ 'CSSMI', 'name' } ) > 0 );
ok( $quotes{ 'CSSMI', 'success' } );
ok( $quotes{ 'CSSMI', 'currency' } eq 'CHF' );
ok(    substr( $quotes{ 'CSSMI', 'isodate' }, 0, 4 ) == $year
    || substr( $quotes{ 'CSSMI', 'isodate' }, 0, 4 ) == $lastyear );
ok(    substr( $quotes{ 'CSSMI', 'date' }, 6, 4 ) == $year
    || substr( $quotes{ 'CSSMI', 'date' }, 6, 4 ) == $lastyear );

# Make sure we don't have spurious % signs.
ok( $quotes{ 'CSSMI', 'p_change' } !~ /%/ );

# Check that a bogus stock returns no-success.
ok( !$quotes{ 'BOGUS', 'success' } );
