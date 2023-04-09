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

my %valid    = ('VWAGY'        => 'Volkswagen ADR',
                'Volkswagen'   => 'Volkswagen VZ',
                'DE0007664039' => 'Volkswagen VZ'
               );

my @invalid  = ('BOGUS');
my @symbols  = (keys %valid, @invalid);

my $method   = 'comdirect';   # Name of the target method for testing
my $currency = 'EUR';         # expected quote curreny
my $today    = today();       # together with $window, validate date/isodate  
my $window   = 7;             # quote must be within last $window days

my %check    = (# Tests are called with (value_to_test, symbol, quote_hash_reference)
                'success'  => sub {$_[0] == 1},
                'method'   => sub {$_[0] eq 'comdirect'},
                'open'     => sub {not defined $_[0] or looks_like_number($_[0])},
                'low'      => sub {not defined $_[0] or looks_like_number($_[0])},
                'high'     => sub {not defined $_[0] or looks_like_number($_[0])},
                'last'     => sub {not defined $_[0] or looks_like_number($_[0])},
                'currency' => sub {$_[0] =~ /^[A-Z]{3}$/},
                'name'     => sub {$_[0] eq $valid{$_[1]}},
                'isin'     => sub {$_[0] =~ /^[A-Z0-9]{12}$/},
                'isodate'  => sub {defined $_[0] and Date::Range->new($today - $window, $today)->includes(Date::Simple::ISO->new($_[0]))},
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

