#!/usr/bin/perl -w

# Copyright (C) 2013, Sam Morris <sam@robots.org.uk>
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use Test::More;
use Finance::Quote;

my @methods = qw/mtgox bitcoin/;
my @markets =
    qw/USD EUR JPY CAD GBP CHF RUB AUD SEK DKK HKD PLN CNY SGD THB NZD NOK/;

plan tests => 48;

my $q = Finance::Quote->new;

for my $method (@methods) {
    for my $market (@markets) {
        cmp_ok( sprintf( "%s_%s", $method, lc $market ), '~~', $q->sources );
    }
}

SKIP: {
    skip 'Set $ENV{ONLINE_TEST} to run these tests', 14
        unless $ENV{ONLINE_TEST};

    my %data = $q->fetch( "mtgox_eur", "BTC", "xyz", "thisisfartoolong" );
    ok(%data);
    is( $data{ "xyz", "success" },  0 );
    is( $data{ "xyz", "errormsg" }, "HTTP failure" );

    is( $data{ "thisisfartoolong", "success" },  0 );
    is( $data{ "thisisfartoolong", "errormsg" }, "Symbol too long" );

    is( $data{ "BTC", "success" }, 1 );
    is( $data{ "BTC", "symbol" },  "BTC" );
    like( $data{ "BTC", "last" }, '/^[\d]+\.?[\d]*$/' );
    cmp_ok( $data{ "BTC", "bid" }, "<", $data{ "BTC", "ask" } );
    like( $data{ "BTC", "date" }, '/^\d{1,2}\/\d{1,2}\/\d{1,2}$/' );
    like( $data{ "BTC", "time" }, '/^\d{1,2}:\d{1,2}:\d{1,2}$/' );
    is( $data{ "BTC", "method" },   "mtgox_eur" );
    is( $data{ "BTC", "exchange" }, "Mt.Gox" );
    is( $data{ "BTC", "timezone" }, "UTC" );
}
