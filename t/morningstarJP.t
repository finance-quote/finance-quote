#!/usr/bin/perl -w
use strict;
use Test::More;
use DateTime;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 10 * 2;

# Find out today
my $calcDay = DateTime->now();
my $year  = $calcDay->year();
my $month = $calcDay->month();
my $day   = $calcDay->day();

# Test Morningstar JP functions.

my $q = Finance::Quote->new();
my @funds = ( "2009100101", "2002013108" );

my %info = $q->morningstarjp(@funds);
ok(%info);

### %info
# Check that the symbol/name, date, currency and nav defined for all of the funds.
foreach my $fund (@funds)
{
  ok( $info{ $fund, "success" }, 'success' );

  # Price date should be within 10 days of today, but we will allow +- 1 day
  # on top of that for running tests outside of Asia/Tokyo timezone
  my $fndyear  = substr( $info{ $fund, "isodate" }, 0, 4 );
  my $fndmonth = substr( $info{ $fund, "isodate" }, 5, 2 );
  my $fndday   = substr( $info{ $fund, "isodate" }, 8, 2 );

  my $fnd = DateTime->new(year=>$fndyear,month=>$fndmonth,day=>$fndday);
  my $deltadays = $calcDay->subtract_datetime($fnd)->in_units('days');

  cmp_ok( $deltadays,'<=', 11, 'not more than 11 days before today' );
  cmp_ok( $deltadays,'>=', -1, 'not more than 1 day in the future' );

  cmp_ok( $info{ $fund, 'currency' }, 'eq', 'JPY',           'currency' );
  cmp_ok( $info{ $fund, 'method' },   'eq', 'MorningstarJP', 'method' );
  cmp_ok( $info{ $fund, 'name' },     'ne', '',              'name' );
  cmp_ok( $info{ $fund, "price" },    '>',  0,               'price' );
  cmp_ok( $info{ $fund, "nav" },      '>',  0,               'nav' );
  cmp_ok( $info{ $fund, 'symbol' },   'eq', $fund,           'symbol' );
}

# Check that a bogus symbol returns no-success.
ok( !$info{ "BOGUS", "success" } );
