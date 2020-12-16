#!/usr/bin/perl -w

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, Smart::Comments;

use strict;
use Test::More;
use Finance::Quote;
use Scalar::Util qw(looks_like_number);
use Date::Simple qw(today);
use Date::Range;
use Date::Manip;

if ( not $ENV{ONLINE_TEST} ) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

# Bourso tests need to cover all the possible cases:
#
#    Name		What		Test Case
#
#    action	        Stock		1rPAF, MSFT, FF11-SOLB, 1rPSOLB, 1rPCNP
#    obligation	        Bond		1rPFR0010371401
#    opcvm	        Fund		MP-802941
#    warrant	        Warrant		1rAHX70B - expired & removed from tests
#    indice	        Index		1rPCAC
#    tracker            Tracker         1rTBX4

my %valid    = ('MP-802941'       => {currency => 'EUR', days =>  32, name => 'Covéa Actions Asie C'},            # Fund, EUR
                '1rPAF'           => {currency => 'EUR', days =>   7, name => 'AIR FRANCE-KLM'},                  # Stock, EUR, Euronext Paris
                'MSFT'            => {currency => 'USD', days =>   7, name => 'MICROSOFT'},                       # Stock, USD, NASDAQ
                'FF11-SOLB'       => {currency => 'EUR', days =>   7, name => 'SOLVAY'},                          # Stock, EUR, Euronext Bruxelles
                '1rPSOLB'         => {currency => 'EUR', days =>  32, name => 'SOLVAY'},                          # Stock, EUR, Euronext Paris
                '1rPCNP'          => {currency => 'EUR', days =>   7, name => 'CNP ASSURANCES'},                  # Stock, EUR, Euronext Paris
                '2rPDE000CX0QLH6' => {currency => 'EUR', days =>   7, name => 'GOLD/CITI WT OPEN'},               # Warrant
                '1rPFR0010371401' => {currency => '%'  , days => 100, name => 'FRENCH REPUBLIC 4% 25/10/38 EUR'}, # Bond, EUR, Euronext Paris,
                '1rPCAC'          => {currency => 'Pts', days =>   7, name => 'CAC 40'},                          # Index, Pts, Paris,
                '1rTBX4'          => {currency => 'EUR', days =>   7, name => 'LYXOR ETF BX4'},                   # Tracker, EUR
                );
my %invalid  = ('BOGUS' => undef);
my @symbols  = (keys %valid, keys %invalid);
my $today    = today();
my %check    = (# Tests are called with (value_to_test, symbol, quote_hash_reference)
                'name'     => sub {$valid{$_[1]}{name}     eq $_[0]},              # @_ = (value, symbol)
                'currency' => sub {$valid{$_[1]}{currency} eq $_[0]},              #
                'method'   => sub {$_[0] eq 'bourso'},                             #
                'success'  => sub {$_[0]},                                         #
                'volume'   => sub {defined $_[0] ? looks_like_number($_[0]) : 1},  # volume is optional
                'close'    => sub {defined $_[0] ? looks_like_number($_[0]) : 1},  # close is optional
                'last'     => sub {looks_like_number($_[0])},                      # last is REQUIRED
                'high'     => sub {defined $_[0] ? looks_like_number($_[0]) : 1},  # high is optional
                'low'      => sub {defined $_[0] ? looks_like_number($_[0]) : 1},  # low is optional
                'net'      => sub {defined $_[0] ? looks_like_number($_[0]) : 1},  # net is optional
                'exchange' => sub {defined $_[0] ? $_[0] =~ /^[A-Z]+$/ : 1},       # exchange is optional
                'isodate'  => sub {Date::Range->new($today - $valid{$_[1]}{days}, $today)->includes(Date::Simple::ISO->new($_[0]))},
                'date'     => sub {my $a = Date::Manip::Date->new(); $a->parse_format('%m/%d/%Y', $_[0]);
                                   my $b = Date::Manip::Date->new(); $b->parse_format('%Y-%m-%d', $_[2]->{$_[1], 'isodate'});
                                   return $a->cmp($b) == 0;},
               );
my $q        = Finance::Quote->new();


plan tests => 1 + %check*%valid + %invalid;

my %quotes = $q->fetch('bourso', @symbols);
ok(%quotes);

### [<now>] quotes: %quotes

foreach my $symbol (keys %valid) {
  while (my ($key, $lambda) = each %check) {
    ### check key: $key
    ### check res: $quotes{$symbol, $key}
    ok($lambda->($quotes{$symbol, $key}, $symbol, \%quotes), 
       defined $quotes{$symbol, $key} 
          ? "$key -> $quotes{$symbol, $key}"
          : "$key -> <undefined>");
  }
}
    
foreach my $symbol (keys %invalid) {
  ok((not $quotes{'BOGUS', 'success'}), 'failed as expected');
}

