#!/usr/bin/perl -w

use strict;
use warnings;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use Test::More;
use Finance::Quote;
use DateTime qw(now);
use DateTime::Duration;
use DateTime::Format::ISO8601;
use Date::Manip;
use Scalar::Util qw(looks_like_number);

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

my %valid    = ('MNW' => 'Manawa Energy Limited Ordinary Shares');
my @invalid  = ('BOGUS');
my @symbols  = (keys %valid, @invalid);

my $method   = 'nzx';                                              # Name of the target method for testing
my $currency = 'NZD';                                              # expected quote curreny
my $today    = DateTime->now()->set_time_zone('Pacific/Auckland'); # together with $window, validate date/isodate
my $window   = $today - DateTime::Duration->new(days => 7);        # quote must be within last $window days

my %check    = (# Tests are called with (value_to_test, symbol, quote_hash_reference)
                'success'  => sub {$_[0] == 1},
                'last'     => sub {looks_like_number($_[0])},
                'isin'     => sub {$_[0] =~ /^[A-Z0-9]{12}$/},
                'name'     => sub {$_[0] eq $valid{$_[1]}},
                'currency' => sub {$_[0] eq $currency},
                'isodate'  => sub {DateTime->compare($window, DateTime::Format::ISO8601->parse_datetime($_[0])) < 0},
                'date'     => sub {my $a = Date::Manip::Date->new(); $a->parse_format('%m/%d/%Y', $_[0]);
                                   my $b = Date::Manip::Date->new(); $b->parse_format('%Y-%m-%d', $_[2]->{$_[1], 'isodate'});
                                   return $a->cmp($b) == 0;}
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

