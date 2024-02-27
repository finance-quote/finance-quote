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

my @valid    = ('DE0008404005', 'NL0011540547', 'FR0000120628', 'XS2630111719', 'NL0000009165');
my @invalid  = ('BOGUS');
my @symbols  = (@valid, @invalid);
my $today    = today();
my $window   = 32;   # XS2630111719 quotes are only updates 1-2 a month

my %check    = (# Tests are called with (value_to_test, symbol, quote_hash_reference)
                'success'  => sub {$_[0]},
                'last'     => sub {looks_like_number($_[0])},
                'volume'   => sub {looks_like_number($_[0])},
                'price'    => sub {looks_like_number($_[0])},
                'close'    => sub {looks_like_number($_[0])},
                'change'   => sub {looks_like_number($_[0])},
                'p_change' => sub {looks_like_number($_[0])},
                'isodate'  => sub {Date::Range->new($today - $window, $today)->includes(Date::Simple::ISO->new($_[0]))},
                'date'     => sub {my $a = Date::Manip::Date->new(); $a->parse_format('%m/%d/%Y', $_[0]);
                                   my $b = Date::Manip::Date->new(); $b->parse_format('%Y-%m-%d', $_[2]->{$_[1], 'isodate'});
                                   return $a->cmp($b) == 0;},
               );

plan tests => 2 * (1 + %check * @valid + @invalid);

my $q1      = Finance::Quote->new();
my %quotes1 = $q1->fetch('tradegate', @symbols);
my $q2      = Finance::Quote->new('Tradegate', 'tradegate' => {INST_ID => '0000003'});
my %quotes2 = $q2->fetch('tradegate', @symbols);
ok(%quotes1);
ok(%quotes2);

### [<now>] quotes1: %quotes1
### [<now>] quotes2: %quotes2

foreach my $symbol (@valid) {
  while (my ($key, $lambda) = each %check) {
    ok($lambda->($quotes1{$symbol, $key}, $symbol, \%quotes1), "$symbol: $key -> $quotes1{$symbol, $key}");
    ok($lambda->($quotes2{$symbol, $key}, $symbol, \%quotes2), "$symbol: $key -> $quotes2{$symbol, $key}");
  }
}
    
foreach my $symbol (@invalid) {
  ok((not $quotes1{'BOGUS', 'success'}), 'failed as expected');
  ok((not $quotes2{'BOGUS', 'success'}), 'failed as expected');
}

