#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 4};

use Finance::Quote;

# Test currency conversion;

my $q      = Finance::Quote->new();

ok($q->currency("USD","AUD"));
ok($q->currency("EUR","JPY"));
ok(! defined($q->currency("XXX","YYY")));
ok(($q->currency("10 AUD","AUD")) == (10 * ($q->currency("AUD","AUD"))));
