#!/usr/bin/perl -w
use strict;
use Test::More;

plan tests => 4;

use Finance::Quote;
ok(1, "Finance::Quote loaded");

my $q = Finance::Quote->new();
ok( $q, "bare constructor");

ok( $q->B_to_billions("1.234B") eq "1234000000", "B_to_billions check");
ok( $q->decimal_shiftup("6.789", 2) eq "678.9", "decimal_shiftup test");



