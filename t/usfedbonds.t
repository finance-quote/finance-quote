#!/usr/bin/perl -w

use strict;
use warnings;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use Test::More;
use Finance::Quote;
use Date::Simple qw(today);
use Scalar::Util qw(looks_like_number);
use Date::Range;
use Date::Manip;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

my %valid    = ('E197001.200606' => '137.00',
                'E194112.200610' => '94.35',
                'E194105.200610' => '90.59',
                'S196712.202006' => '156.28');
my @invalid  = ('BOGUS');
my @symbols  = (keys %valid, @invalid);

my $method   = 'usfedbonds';    # Name of the target method for testing
my $currency = 'USD';           # expected quote curreny

my %check    = (# Tests are called with (value_to_test, symbol, quote_hash_reference)
                'price'    => sub {looks_like_number($_[0]) && $_[0] eq $valid{$_[1]}},
                'currency' => sub {$_[0] eq $currency},
                'date'     => sub {$_[0] =~ m,^[0-9]{2}/[0-9]{2}/[0-9]{4},},
                'isodate'  => sub {$_[0] =~ m,[0-9]{4}-[0-9]{2}-[0-9]{2},},
                'success'  => sub {$_[0] == 1},
              );
my $q        = Finance::Quote->new();

plan tests => 1 + %check*%valid + @invalid;

my %quotes = $q->fetch($method, @symbols);
ok(%quotes);

### [<now>] quotes: %quotes

foreach my $symbol (keys %valid) {
  while (my ($key, $lambda) = each %check) {
    ok($lambda->($quotes{$symbol, $key}, $symbol, \%quotes), "$key -> " . (defined $quotes{$symbol, $key} ? $quotes{$symbol, $key} : '<undefined>'));
  }
}
    
foreach my $symbol (@invalid) {
  ok((not $quotes{'BOGUS', 'success'}), 'failed as expected');
}

