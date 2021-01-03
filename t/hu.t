#!/usr/bin/perl -w
#
# HU.pm
#
# Version 0.1 - test of Hungarian (HU) F::Q
# This version based on za.t module
#
# Zoltan Levardy <zoltan at levardy dot org>
# 2009
# 2019-06-22: Removed failing fund, replaced with HU0000705280.
#  Surrounded failing equity check for OTP in a TODO block.
#  Bruce Schuck <bschuck at asgard hyphen systems dot com>

use strict;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use Test::More;
use Finance::Quote;

if ( not $ENV{ONLINE_TEST} ) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 21;

# Test za functions.

my $q        = Finance::Quote->new("HU");
my $year     = ( localtime() )[5] + 1900;
my $lastyear = $year - 1;

# getting quotes for shares by ticker (OTP, MTELEKOM)
# funds by ISIN (HU0000702709,HU0000706437)
# and finally an incorrect ticker/isin is ZOL, must fail.
my %quotes = $q->hu( "OTP", "HU0000705280", "HU0000702709", "ZOL" );
ok(%quotes);

### quotes : %quotes

# Check that the last and date values are defined.
ok( $quotes{ "OTP", "success" } );
ok( $quotes{ "OTP", "last" } > 0 );
ok( length( $quotes{ "OTP", "date" } ) > 0 );
ok(    substr( $quotes{ "OTP", "isodate" }, 0, 4 ) == $year
    || substr( $quotes{ "OTP", "isodate" }, 0, 4 ) == $lastyear );
ok(    substr( $quotes{ "OTP", "date" }, 6, 4 ) == $year
    || substr( $quotes{ "OTP", "date" }, 6, 4 ) == $lastyear );
ok( $quotes{ "OTP", "currency" } eq "HUF" );

# MKB HUF Liquidity Fund: HU0000705280
ok( $quotes{ "HU0000705280", "success" } );
ok( $quotes{ "HU0000705280", "last" } > 0 );
ok( length( $quotes{ "HU0000705280", "date" } ) > 0 );
ok(    substr( $quotes{ "HU0000705280", "isodate" }, 0, 4 ) == $year
    || substr( $quotes{ "HU0000705280", "isodate" }, 0, 4 ) == $lastyear );
ok(    substr( $quotes{ "HU0000705280", "date" }, 6, 4 ) == $year
    || substr( $quotes{ "HU0000705280", "date" }, 6, 4 ) == $lastyear );
ok( $quotes{ "HU0000705280", "currency" } eq "HUF" );

# Fund: Budapest II, isin: HU0000702709
ok( $quotes{ "HU0000702709", "success" } );
ok( $quotes{ "HU0000702709", "last" } > 0 );
ok( length( $quotes{ "HU0000702709", "date" } ) > 0 );
ok(    substr( $quotes{ "HU0000702709", "isodate" }, 0, 4 ) == $year
    || substr( $quotes{ "HU0000702709", "isodate" }, 0, 4 ) == $lastyear );
ok(    substr( $quotes{ "HU0000702709", "date" }, 6, 4 ) == $year
    || substr( $quotes{ "HU0000702709", "date" }, 6, 4 ) == $lastyear );
ok( $quotes{ "HU0000702709", "currency" } eq "HUF" );

# Check that a ZOL fund returns no-success.
ok( !$quotes{ "ZOL", "success" } );
ok( $quotes{ "ZOL",  "errormsg" } eq "Fetch from bse or bamosz failed" );
