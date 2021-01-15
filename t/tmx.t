#!/usr/bin/perl -w

use strict;
use warnings;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use Test::More;
use Finance::Quote;
use Scalar::Util qw(looks_like_number);

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

my %valid    = ('STN' => 'Stantec Inc.',
                'BCE' => 'BCE Inc.',
                'BMO' => 'Bank of Montreal'
               );
my @invalid  = ('BOGUS');
my @symbols  = (keys %valid, @invalid);

my $method   = 'tmx';    # Name of the target method for testing

my %check    = (# Tests are called with (value_to_test, symbol, quote_hash_reference)
                'success'  => sub {$_[0] == 1},
                'name'     => sub {$_[0] eq $valid{$_[1]}},
                'year_range' => sub {$_[0] =~ /[0-9.]+ - [0-9.]+/},
                'exchange' => sub {$_[0] eq 'Toronto Stock Exchange'},
                'symbol'   => sub {$_[0] =~ /^$_[1](:CA)?$/},
                'high'   => sub {looks_like_number($_[0])},
                'low'   => sub {looks_like_number($_[0])},
                'open'   => sub {looks_like_number($_[0])},
                'close'   => sub {looks_like_number($_[0])},
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

