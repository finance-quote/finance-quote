#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote::Currencies;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 1;

my $known_currencies
  = eval { Finance::Quote::Currencies::known_currencies() };
my $live_currencies
  = eval { Finance::Quote::Currencies::fetch_live_currencies() };

is_deeply( $known_currencies
         , $live_currencies
         , "Stored currency list is up to date with live currency list"
         );
