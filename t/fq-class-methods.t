#!/usr/bin/perl -w
use strict;
use Test::More;

plan tests => 7;

use Finance::Quote;
ok(1, "Finance::Quote loaded");

my @target = qw/last high low net bid ask close open day_range year_range eps div cap nav price/;
my @result = Finance::Quote::get_default_currency_fields();
ok( join(",", sort @target) eq join(",", sort @result), "get_default_currency_fields check");

my $timeout = Finance::Quote::get_default_timeout();
ok( !defined $timeout, "check default timeout is undef");

my @methods = Finance::Quote::get_methods();
ok( grep( /alphavantage/, @methods), "check for a known method");

# new tested in fq-object-methods.t

ok( Finance::Quote::scale_field("1023","0.01") eq "10.23", "check scale_field");

Finance::Quote::set_default_timeout(4);
ok( Finance::Quote::get_default_timeout() == 4, "check set/get default timeout");

my $t4 = Finance::Quote->new();
ok( $t4->get_timeout() == 4, "check default timeout was used");
