#!/usr/bin/perl -w
use strict;
use warnings;
use Scalar::Util qw(looks_like_number);
use Finance::Quote;
use Test::More;
use Time::Piece;
use feature 'say';

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 6;

# Listed securities come and go, so entries on these lists will eventually fail.
my @ordinaries = qw/ARG BHP CBA RIO/;
my @numerics   = qw/360 14D A2M XF1/;
my @corp_bonds = qw/ANZPH AYUHD IAGPD NABHA/;
my @govt_bonds = qw/GSBK51 GSIC50/;
my @etps       = qw/BEAR ETPMPT GOLD IAA/;
my @warrants   = qw/BHPSOA/;
my @indices    = qw/XAO XJO/;
my @invalids   = qw/BOGUS TooLong Non-AN/;

my ($q, %quotes);

subtest 'Startup: Test object creation' => sub {
	$q = new_ok( 'Finance::Quote' );
};

subtest 'Test the "normal" securities that use the Primary ASX data source' => sub {
	ok( %quotes = $q->asx(@ordinaries, @numerics), 'fetch quotes' );

	for my $symbol (@ordinaries, @numerics) {

		ok( $quotes{$symbol, 'success'} == 1,      "Success for $symbol"   );

		subtest "Data tests for $symbol" => sub {
			plan 'skip_all' => "Bypass data tests for $symbol - no data returned" unless $quotes{$symbol, 'success'} == 1;
			plan tests => 22;

			ok( $quotes{$symbol, 'errormsg'} eq '',    'no error message for valid symbol' );
			ok( $quotes{$symbol, 'currency'} eq 'AUD', 'got expected currency' );
			ok( $quotes{$symbol, 'method'  } eq 'asx', 'got expected method'   );

			ok( length $quotes{$symbol,'name'},        'got a name'            );
			ok( $quotes{$symbol,'symbol'} eq $symbol,  'matching symbol'       );

			ok( $quotes{$symbol, 'exchange'} eq 'Australian Securities Exchange',
				'got expected exchange' );

			my $date = Time::Piece->strptime($quotes{$symbol,'date'}, '%m/%d/%Y');
			ok( $date >= localtime()->add_years(-1), 'date less than a year ago' );
			my $isodate = Time::Piece->strptime($quotes{$symbol,'isodate'}, '%Y-%m-%d');
			ok( $isodate >= localtime()->add_years(-1), 'isodate less than a year ago' );

# For the securities in this group, expect *all* prices and volume to have non-zero values.
# (The occasional trading halt or corporate action may cause some of these to fail - c'est la vie.)
			for my $field (qw/ask bid close high last low open price volume/) {
				ok( $quotes{$symbol, $field} > 0, "$field > 0" );
			}

			for my $field (qw/cap eps net p_change pe/) {
				ok( looks_like_number($quotes{$symbol, $field}),
					"$field looks like a number" );
			}

			done_testing();
		};
	}
	done_testing();
};

subtest 'Test the "other" security types, many of which use the Alternate ASX data source' => sub {
	ok( %quotes = $q->asx(@corp_bonds, @govt_bonds, @etps, ), 'fetch quotes' );

	for my $symbol (@corp_bonds, @govt_bonds, @etps) {

		ok( $quotes{$symbol, 'success'} == 1,      "success for $symbol"   );

		subtest "Data tests for $symbol" => sub {
			plan 'skip_all' => "Bypass data tests for $symbol - no data returned" unless $quotes{$symbol, 'success'} == 1;
			plan tests => 13;

			ok( $quotes{$symbol, 'errormsg'} eq '',    'no error message for valid symbol' );
			ok( $quotes{$symbol, 'currency'} eq 'AUD', 'got expected currency' );
			ok( $quotes{$symbol, 'method'  } eq 'asx', 'got expected method'   );

			ok( length $quotes{$symbol,'name'},        'got a name'            );
			ok( $quotes{$symbol,'symbol'} eq $symbol,  'matching symbol'       );

			ok( $quotes{$symbol, 'exchange'} eq 'Australian Securities Exchange',
				'got expected exchange' );

# For the securities in this group, only expect the prices to have non-zero values.
			for my $field (qw/last price/) {
				ok( $quotes{$symbol, $field} > 0, "$field > 0" );
			}

			for my $field (qw/ask bid/) {
				SKIP: {
					skip "Bypass check for '$field' if not received", 1 if $quotes{$symbol, $field} eq '';
					ok( looks_like_number($quotes{$symbol, $field}),
						"$field looks like a number" );

				}
			}

			for my $field (qw/net p_change volume/) {
				ok( looks_like_number($quotes{$symbol, $field}),
					"$field looks like a number" );
			}

			done_testing();
		};
	}
	done_testing();
};

subtest 'Test the "warrants and options" security types, which use the Alternate ASX data source and are thinly traded' => sub {
	ok( %quotes = $q->asx(@warrants), 'fetch quotes' );

	for my $symbol (@warrants) {

		ok( $quotes{$symbol, 'success'} == 1,      "success for $symbol"   );

		subtest "Data tests for $symbol" => sub {
			plan 'skip_all' => "Bypass data tests for $symbol - no data returned" unless $quotes{$symbol, 'success'} == 1;
			plan tests => 12;

			ok( $quotes{$symbol, 'errormsg'} eq '',    'no error message for valid symbol' );
			ok( $quotes{$symbol, 'currency'} eq 'AUD', 'got expected currency' );
			ok( $quotes{$symbol, 'method'  } eq 'asx', 'got expected method'   );

			ok( length $quotes{$symbol,'name'},        'got a name'            );
			ok( length $quotes{$symbol,'type'},        'got a type'            );
			ok( $quotes{$symbol,'symbol'} eq $symbol,  'matching symbol'       );

			ok( $quotes{$symbol, 'exchange'} eq 'Australian Securities Exchange',
				'got expected exchange' );

# For the securities in this group, only check for numeric values.
			for my $field (qw/last price net p_change volume/) {
				ok( looks_like_number($quotes{$symbol, $field}),
					"$field looks like a number" );
			}

			done_testing();
		};
	}
	done_testing();
};

subtest 'Test the indexes, which use the Alternate ASX data source' => sub {
	ok( %quotes = $q->asx(@indices), 'fetch quotes' );

	for my $symbol (@indices) {

		ok( $quotes{$symbol, 'success'} == 1,      "success for $symbol"   );

		subtest "Data tests for $symbol" => sub {
			plan 'skip_all' => "Bypass data tests for $symbol - no data returned" unless $quotes{$symbol, 'success'} == 1;
			plan tests => 10;

			ok( $quotes{$symbol, 'errormsg'} eq '',    'no error message for valid symbol' );
			ok( $quotes{$symbol, 'method'  } eq 'asx', 'got expected method'   );

			ok( length $quotes{$symbol,'name'},        'got a name'            );
			ok( $quotes{$symbol,'symbol'} eq $symbol,  'matching symbol'       );

			ok( $quotes{$symbol, 'exchange'} eq 'Australian Securities Exchange',
				'got expected exchange' );

# Indices should have non-zero prices and volumes.
			for my $field (qw/last price volume/) {
				ok( $quotes{$symbol, $field} > 0, "$field > 0" );
			}

			for my $field (qw/net p_change/) {
				ok( looks_like_number($quotes{$symbol, $field}),
					"$field looks like number" );
			}

			done_testing();
		};
	}
	done_testing();
};

subtest 'Test that invalid symbols fail properly' => sub {
	ok( %quotes = $q->asx(@invalids), 'fetch quotes' );

	for my $symbol (@invalids) {

		subtest "Data tests for $symbol" => sub {
			plan tests => 2;

			ok( !$quotes{$symbol, 'success'},      , 'bad symbol returned no result'    );
			ok( $quotes{$symbol,  'errormsg'} ne '', 'got error message for bad symbol' );

			done_testing();
		};

	}
	done_testing();
};

done_testing();
