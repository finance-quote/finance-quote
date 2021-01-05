#!/usr/bin/perl -w

use strict;

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

my @valid    = ('AD', 'AMG', 'LVMH', 'XS0937858271', 'NL0000009165');
my @invalid  = ('BOGUS');
my @symbols  = (@valid, @invalid);
my $today    = today();
my $window   = 32;   # XS0937858271 quotes are only updates 1-2 a month

my %check    = (# Tests are called with (value_to_test, symbol, quote_hash_reference)
                'success' => sub {$_[0]},
                'last'    => sub {looks_like_number($_[0])},
                'volume'  => sub {looks_like_number($_[0])},
                'isodate' => sub {Date::Range->new($today - $window, $today)->includes(Date::Simple::ISO->new($_[0]))},
                'date'    => sub {my $a = Date::Manip::Date->new(); $a->parse_format('%m/%d/%Y', $_[0]);
                                  my $b = Date::Manip::Date->new(); $b->parse_format('%Y-%m-%d', $_[2]->{$_[1], 'isodate'});
                                  return $a->cmp($b) == 0;},
               );
my $q        = Finance::Quote->new();

plan tests => 1 + %check*@valid + @invalid;

my %quotes = $q->fetch('aex', @symbols);
ok(%quotes);

### [<now>] quotes: %quotes

foreach my $symbol (@valid) {
  while (my ($key, $lambda) = each %check) {
    ok($lambda->($quotes{$symbol, $key}, $symbol, \%quotes), "$symbol: $key -> $quotes{$symbol, $key}");
  }
}
    
foreach my $symbol (@invalid) {
  ok((not $quotes{'BOGUS', 'success'}), 'failed as expected');
}

