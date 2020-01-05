#!/usr/bin/perl -w
use strict;
use Test::More;

plan tests => 3;

use Finance::Quote;
ok(1, "Finance::Quote loaded");

my @sources = Finance::Quote->get_sources();
ok( grep( /alphavantage/, @sources), "check for a known source");

my @target = qw/last high low net bid ask close open day_range year_range eps div cap nav price/;
my @result = Finance::Quote->get_default_currency_fields();
ok( join(",", sort @target) eq join(",", sort @result), "get_default_currency_fields check");




