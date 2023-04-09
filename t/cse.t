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

my %valid    = ('JKH.N0000'  => 'JOHN KEELLS HOLDINGS PLC',
                'ACME.N0000' => 'ACME PRINTING & PACKAGING PLC');
my @invalid  = ('BOGUS');
my @symbols  = (keys %valid, @invalid);

my $method   = 'cse';    # Name of the target method for testing
my $currency = 'LKR';    # expected quote curreny

my %check    = (# Tests are called with (value_to_test, symbol, quote_hash_reference)
                'isin'     => sub {$_[0] =~ /^[A-Z0-9]{12}$/},
                'close'    => sub {looks_like_number($_[0])},
                'last'     => sub {looks_like_number($_[0])},
                'high'     => sub {looks_like_number($_[0])},
                'low'      => sub {looks_like_number($_[0])},
                'cap'      => sub {looks_like_number($_[0])},
                'name'     => sub {$_[0] eq $valid{$_[1]}},
                'currency' => sub {$_[0] =~ /^[A-Z]{3}$/},
                'success'  => sub {$_[0] == 1}
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

