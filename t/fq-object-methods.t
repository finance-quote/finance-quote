#!/usr/bin/perl -w
use strict;
use Test::More;

plan tests => 3;

use Finance::Quote;
ok(1, "Finance::Quote loaded");

my $q = Finance::Quote->new();
ok( $q, "bare constructor");

ok( $q->B_to_billions("1.234B") eq "1234000000", "B_to_billions check");




