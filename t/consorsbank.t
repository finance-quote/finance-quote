#!/usr/bin/perl -w
use strict;
use warnings;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use Test::More;
use Finance::Quote;
use Scalar::Util qw(looks_like_number);
use Date::Simple qw(today);
use Date::Range;
use Date::Manip;

if ( not $ENV{ONLINE_TEST} ) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

my $CONSORS_SOURCE_BASE_URL = 'https://www.consorsbank.de/web/Wertpapier/';

# Test cases for Consorsbank

my %valid    = (
    'DE0007664005' => {currency => 'EUR', days => 3, name => 'VOLKSWAGEN AG'},              # Stock (ISIN), EUR
    '766400'       => {currency => 'EUR', days => 3, name => 'VOLKSWAGEN AG'},              # Stock (WKN), EUR

    'DE0008469008' => {currency => 'EUR', days => 7, name => 'DAX PERFORMANCE INDEX'},      # Index: DAX
    'FR0003500008' => {currency => 'EUR', days => 7, name => 'CAC 40 INDEX'},               # Index: CAC 40
    '_81341467'    => {currency => 'USD', days => 7, name => 'S&P 500 (BNPP INDICATION)'},  # Index (Consors internal ID)

    'DE0001102580' => {currency => 'EUR', days => 7, name => 'BUNDESREP.DEUTSCHLAND ANL.V.2022 (2032)'},  # Bond
    'FR0010411884' => {currency => 'EUR', days => 7, name => 'Amundi CAC 40 Daily (-2x) Invrse ETF Acc'}, # ETF, EUR
    'LU1508476725' => {currency => 'EUR', days => 7, name => 'Allianz Global Equity Insights A EUR'},     # Fund, EUR
    'EU0009652759' => {currency => 'USD', days => 7, name => 'EURO / US-DOLLAR (EUR/USD)'}, # Currency
);

my %invalid  = (
    'FR0010037341' => undef, # known by Consors, but no prices tracked on default exchange
    'DE000DB4CAT1' => undef, # Commodities: Brent
    'BOGUS' => undef,
);

my @symbols  = (keys %valid, keys %invalid);
my $today    = today();

my %check    = (# Tests are called with (value_to_test, symbol, quote_hash_reference)
    'success'  => sub {$_[0]},
    'symbol'   => sub {$_[0] eq $_[1]},
    'name'     => sub {$_[0] eq $valid{$_[1]}{name}},
    'method'   => sub {$_[0] eq 'consorsbank'},
    'source'   => sub {$_[0] eq $CONSORS_SOURCE_BASE_URL . $_[1]},
    'exchange' => sub {$_[0] =~ /^.+$/},
    'currency' => sub {defined $valid{$_[1]}{currency} ? $_[0] eq $valid{$_[1]}{currency} : 1},
    'last'     => sub {looks_like_number($_[0])},                      # last is REQUIRED

    'ask'      => sub {defined $_[0] ? looks_like_number($_[0]) : 1},  # ask is optional
    'bid'      => sub {defined $_[0] ? looks_like_number($_[0]) : 1},  # bid is optional
    'close'    => sub {defined $_[0] ? looks_like_number($_[0]) : 1},  # close is optional
    'day_range' => sub {defined $_[0] ? looks_like_number($_[0]) : 1}, # day_range is optional
    'high'     => sub {defined $_[0] ? looks_like_number($_[0]) : 1},  # high is optional
    'low'      => sub {defined $_[0] ? looks_like_number($_[0]) : 1},  # low is optional
    'net'      => sub {defined $_[0] ? looks_like_number($_[0]) : 1},  # net is optional
    'open'     => sub {defined $_[0] ? looks_like_number($_[0]) : 1},  # open is optional
    'p_change' => sub {defined $_[0] ? looks_like_number($_[0]) : 1},  # p_change is optional
    'time'     => sub {defined $_[0] ? $_[0] =~ /^\d{2}:\d{2}$/ : 1},  # time is optional
    'volume'   => sub {defined $_[0] ? looks_like_number($_[0]) : 1},  # volume is optional
    'year_range' => sub {defined $_[0] ? looks_like_number($_[0]) : 1},  # year_range is optional

    'date'     => sub {
        my $a = Date::Manip::Date->new(); $a->parse_format('%m/%d/%Y', $_[0]);
        my $b = Date::Manip::Date->new(); $b->parse_format('%Y-%m-%d', $_[2]->{$_[1], 'isodate'});
        return $_[0] =~ /^\d{2}\/\d{2}\/\d{4}$/ && $a->cmp($b) == 0;},
    'isodate'  => sub {Date::Range->new($today - $valid{$_[1]}{days}, $today)->includes(Date::Simple::ISO->new($_[0]))},
);
my $q = Finance::Quote->new();

plan tests => 1 + %check * %valid + %invalid;

my %quotes = $q->fetch('consorsbank', @symbols);

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

