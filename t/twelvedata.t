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

if ( not $ENV{"TEST_TWELVEDATA_API_KEY"} ) {
    plan skip_all => 'Set $ENV{"TEST_TWELVEDATA_API_KEY"} to run this test';
}

my @valid    = qw/MSFT AMZN AAPL GOOGL META BRK.A/;
my @invalid  = ('BOGUS');
my @symbols  = (@valid, @invalid);

my $q        = Finance::Quote->new('TwelveData', timeout => 120, twelvedata => {API_KEY => $ENV{"TEST_TWELVEDATA_API_KEY"}});
my $today    = today();
my $window   = 7;

my %check    = (# Tests are called with (value_to_test, symbol, quote_hash_reference)
                'success'  => sub {$_[0] == 1},
                'symbol'   => sub {$_[0] eq $_[1]},
                'name'     => sub {defined $_[0]},
                'exchange' => sub {defined $_[0]},
                'currency' => sub {defined $_[0]},
                'open'     => sub {defined $_[0] and looks_like_number($_[0])},
                'high'     => sub {defined $_[0] and looks_like_number($_[0])},
                'low'      => sub {defined $_[0] and looks_like_number($_[0])},
                'close'    => sub {defined $_[0] and looks_like_number($_[0])},
                'volume'   => sub {defined $_[0] and looks_like_number($_[0])},
                'method'   => sub {$_[0] eq 'twelvedata'},
                'isodate'  => sub {Date::Range->new($today - $window, $today)->includes(Date::Simple::ISO->new($_[0]))},
               );

plan tests => 1 + %check*@valid + @invalid;

my %quotes = $q->twelvedata(@symbols);
ok(%quotes);

### [<now>] quotes: %quotes

foreach my $symbol (@valid) {
  while (my ($key, $lambda) = each %check) {
    ok($lambda->($quotes{$symbol, $key}, $symbol, \%quotes), "$key -> " . (defined $quotes{$symbol, $key} ? $quotes{$symbol, $key} : '<undefined>'));
  }
}
    
foreach my $symbol (@invalid) {
  ok((not $quotes{'BOGUS', 'success'}), 'failed as expected');
}

