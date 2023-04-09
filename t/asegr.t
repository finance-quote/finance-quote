#!/usr/bin/perl -w

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, Smart::Comments;

use strict;

use Test::More;
use Finance::Quote;
use Date::Simple qw(today);
use Scalar::Util qw(looks_like_number);
use Date::Range;
use Date::Manip;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

my %skip   = ('bond'       => {'high' => 1, 'low' => 1},
              'derivative' => {'isin' => 1},
              'index'      => {'isin' => 1});

my %valid  = ('CRETA'        => 'stock',
              'KYLO'         => 'stock',
              'ALPHA21U0.80' => 'derivative',
              'AETF'         => 'etf',
              'FORTHB1'      => 'bond',
              'OPAPB2'       => 'bond',
              'FTSE'         => 'index',
              'G210120A2'    => 'bond'
              );

my %invalid  = ('BOGUS' => undef);
my @symbols  = (keys %valid, keys %invalid);
my $today    = today();
my %check    = (# Tests are called with (value_to_test, symbol, quote_hash_reference)
                'close'   => sub {looks_like_number($_[0])},
                'volume'  => sub {looks_like_number($_[0])},
                'high'    => sub {looks_like_number($_[0])},
                'low'     => sub {looks_like_number($_[0])},
                'isin'    => sub {defined $_[0]},
                'isodate' => sub {Date::Range->new($today - 7, $today)->includes(Date::Simple::ISO->new($_[0]))},
                'date'    => sub {my $a = Date::Manip::Date->new(); $a->parse_format('%m/%d/%Y', $_[0]);
                                  my $b = Date::Manip::Date->new(); $b->parse_format('%Y-%m-%d', $_[2]->{$_[1], 'isodate'});
                                  return $a->cmp($b) == 0;},
 
               );

my $q      = Finance::Quote->new();

plan tests => 1 + %check*%valid + %invalid;

my %quotes = $q->asegr(@symbols);
ok(%quotes);

### [<now>] quotes: %quotes

foreach my $symbol (keys %valid) {
  while (my ($key, $lambda) = each %check) {
    SKIP: {
      skip "$key not required for $symbol", 1 if exists $skip{$valid{$symbol}}->{$key};

      ok((defined $quotes{$symbol, $key} and $lambda->($quotes{$symbol, $key}, $symbol, \%quotes)), 
         (defined $quotes{$symbol, $key} ? "$key -> $quotes{$symbol, $key}" : "$key -> <undefined>"));
    };
  }
}
    
foreach my $symbol (keys %invalid) {
  ok((not $quotes{'BOGUS', 'success'}), 'failed as expected');
}

