#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Finance::Quote;

my @methods = qw/bitstamp bitcoin/;

plan tests => 17;

my $q = Finance::Quote->new;

for my $method (@methods) {
  cmp_ok($method, '~~', $q->sources);
}

SKIP: {
  skip 'Set $ENV{ONLINE_TEST} to run these tests', 15 unless $ENV{ONLINE_TEST};

  my %data = $q->fetch ('bitstamp', 'BTC', 'XYZ');

  ok(%data);

  is($data{'XYZ', 'success'}, 0);
  is($data{'XYZ', 'errormsg'}, 'Symbol not supported');

  is($data{'BTC','success'}, 1);
  is($data{'BTC','symbol'}, 'BTC');
  is($data{'BTC','method'}, 'bitstamp');
  is($data{'BTC','exchange'}, 'Bitstamp');

  like($data{'BTC', $_}, qr/^\d+(?:\.\d+)?$/o) for qw(ask bid high last low volume);

  cmp_ok($data{'BTC','bid'}, '<', $data{'BTC','ask'});
  cmp_ok($data{'BTC','low'}, '<=', $data{'BTC','high'});
}
