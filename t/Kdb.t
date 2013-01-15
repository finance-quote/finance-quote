#!/usr/bin/perl -w
use strict;
use Test::More;
use Date::Calc qw(Today Delta_Days);
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 8 * 2;

# Find out today
my ( $year, $month, $day ) = Today();

# Test Infobank functions.

my $q = Finance::Quote->new();
my @funds = ( "1306", "1321" );

my %info = $q->kdb(@funds);
ok(%info);

# Check that the symbol/name, date, currency and price defined for all of the funds.
foreach my $fund (@funds)
{

  # NAV date should be within 10 days of today, but we will allow +- 1 day
  # on top of that for running tests outside of Asia/Tokyo timezone
  my $fndyear  = substr( $info{ $fund, "date" }, 0, 4 );
  my $fndmonth = substr( $info{ $fund, "date" }, 5, 2 );
  my $fndday   = substr( $info{ $fund, "date" }, 8, 2 );

  cmp_ok( Delta_Days( $fndyear, $fndmonth, $fndday, $year, $month, $day ),
          '<=', 11, 'not more than 11 days before today' );
  cmp_ok( Delta_Days( $fndyear, $fndmonth, $fndday, $year, $month, $day ),
          '>=', -1, 'not more than 1 day in the future' );

  cmp_ok( $info{ $fund, 'currency' }, 'eq', 'JPY', 'currency' );
  cmp_ok( $info{ $fund, 'method' },   'eq', 'Kdb', 'method' );
#  cmp_ok( $info{ $fund, 'name' },     'eq', $fund,           'name' );
  cmp_ok( $info{ $fund, "price" },      '>',  0,               'price' );
  ok( $info{ $fund, "success" }, 'success' );
  cmp_ok( $info{ $fund, 'symbol' }, 'eq', $fund, 'symbol' );
}

# Check that a bogus symbol returns no-success.
ok( !$info{ "BOGUS", "success" } );
