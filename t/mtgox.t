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

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 7;

my $q = Finance::Quote->new ("MtGox");
my %data = $q->fetch ("mtgox_EUR", "BTC", "xyz", "thisisfartoolong");

is($data{"xyz","success"}, 0);
is($data{"xyz","errormsg"}, "HTTP failure");

is($data{"thisisfartoolong","success"}, 0);
is($data{"thisisfartoolong","errormsg"}, "Symbol too long");

is($data{"BTC","success"}, 1);
like($data{"BTC","last"}, '/[0-9]+(\.[0-9]+)?/');
cmp_ok($data{"BTC","bid"}, "<", $data{"BTC","ask"});
