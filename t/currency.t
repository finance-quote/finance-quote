#!/usr/bin/perl -w
# vi: set ts=2 sw=2 noai ic showmode showmatch:  

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, Smart::Comments, '###';

use strict;
use Test::More;
use Finance::Quote;
use Scalar::Util qw(looks_like_number);

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

sub module_check
{
  my ($module, $valid, $invalid, $options) = @_;

  plan tests => 1 + 2*@{$valid} + @{$invalid};
  
  my $hash = {order => [$module]};
  $hash->{lc($module)} = $options if defined $options;

  my $q = Finance::Quote->new('currency_rates' => $hash);
  ok($q);

  foreach my $test (@{$valid}) {
    my ($from, $to) = @{$test};
    my $v = $q->currency($from, $to);
    ok(looks_like_number($v), "$from -> $to = $v");

    my ($from_amount, $from_code) = $from =~ m/^([0-9.]+) ([A-Z]+)$/;
    SKIP: {
      skip "identity check because different currencies", 1 unless $from_code eq $to;

      my ($suffix) = $from_amount =~ m/[.]([0-9]+)/;
      my $string = sprintf("%.*f", length($suffix), $v);

      ok($from_amount eq $string, "identity check");
    };
  }

  foreach my $test (@{$invalid}) {
    my ($from, $to) = @{$test};
    my $v = $q->currency($from, $to);
    is($v, undef, "$from -> $to failed as expected");
  }
}

plan tests => 8;

# Check that FQ fails on bogus CurrencyRates method
my $q = Finance::Quote->new('currency_rates' => {order => ['DoesNotExist']});
ok(not $q);

# Check AlphaVantage
subtest 'AlphaVantage' => sub {
  if ( not $ENV{TEST_ALPHAVANTAGE_API_KEY} ) {
    plan skip_all =>
        'Set $ENV{TEST_ALPHAVANTAGE_API_KEY} to run this test; get one at https://www.alphavantage.co';
  }

  my @valid   = (['1.00 GBP', 'IQD'], ['10.00 AUD', 'AUD']);
  my @invalid = (['20.12 ZZZ', 'GBP']);

  module_check('AlphaVantage', \@valid, \@invalid, {API_KEY => $ENV{TEST_ALPHAVANTAGE_API_KEY}});
};

# Check BankOfItaly
subtest 'BankOfItaly' => sub {
  my @valid   = (['100.00 USD', 'EUR'], ['1.00 GBP', 'IDR'], ['1.23 IDR', 'CAD'], ['10.00 AUD', 'AUD'], ['1.0 INR', 'INR']);
  my @invalid = (['20.12 ZZZ', 'GBP']);

  module_check('BankOfItaly', \@valid, \@invalid);
};

# Check CurrencyFreaks
subtest 'CurrencyFreaks' => sub {
  if ( not $ENV{TEST_CURRENCYFREAKS_API_KEY} ) {
    plan skip_all =>
        'Set $ENV{TEST_CURRENCYFREAKS_API_KEY} to run this test; get one at https://currencyfreaks.com/';
  }

  my @valid   = (['100.00 USD', 'EUR'], ['1.00 GBP', 'IDR'], ['1.23 IDR', 'CAD'], ['10.00 AUD', 'AUD'], ['1.0 INR', 'INR']);
  my @invalid = (['20.12 ZZZ', 'GBP']);

  module_check('CurrencyFreaks', \@valid, \@invalid, {API_KEY => $ENV{TEST_CURRENCYFREAKS_API_KEY}});
};

# Check ECB
subtest 'ECB' => sub {
  my @valid   = (['100.00 USD', 'EUR'], ['1.00 GBP', 'IDR'], ['1.23 IDR', 'CAD'], ['10.00 AUD', 'AUD']);
  my @invalid = (['20.12 ZZZ', 'GBP']);

  module_check('ECB', \@valid, \@invalid);
};

# Check Fixer
subtest 'Fixer' => sub {
  if ( not $ENV{TEST_FIXER_API_KEY} ) {
    plan skip_all =>
        'Set $ENV{TEST_FIXER_API_KEY} to run this test; get one at https://fixer.io';
  }

  my @valid   = (['100.00 USD', 'EUR'], ['1.00 GBP', 'IDR'], ['1.23 IDR', 'CAD'], ['10.00 AUD', 'AUD']);
  my @invalid = (['20.12 ZZZ', 'GBP']);

  module_check('Fixer', \@valid, \@invalid, {cache => 1, API_KEY => $ENV{TEST_FIXER_API_KEY}});
};

# Check FinanceAPI
subtest 'FinanceAPI' => sub {
  if ( not $ENV{TEST_FINANCEAPI_API_KEY} ) {
    plan skip_all =>
        'Set $ENV{TEST_FINANCEAPI_API_KEY} to run this test; get one at https://financeapi.net';
  }

  my @valid   =
    ( ['100.00 USD', 'EUR'], ['1.00 GBP', 'IDR'], ['1.23 IDR', 'CAD'] );
  my @invalid = ( ['20.12 ZZZ', 'GBP'] );

  module_check('FinanceAPI', \@valid, \@invalid, {cache => 1, API_KEY => $ENV{TEST_FINANCEAPI_API_KEY}});
};

# Check FXRatesAPI
subtest 'FXRatesAPI' => sub {
  my @valid   = (['100.00 USD', 'EUR'], ['1.00 GBP', 'IDR'], ['1.23 IDR', 'CAD'], ['10.00 AUD', 'AUD'], ['1.0 INR', 'INR']);
  my @invalid = (['20.12 ZZZ', 'GBP']);

  module_check('FXRatesAPI', \@valid, \@invalid );
};

# Check YahooJSON
subtest 'YahooJSON' => sub {
  my @valid   = (['100.00 USD', 'EUR'], ['1.00 GBP', 'IDR'], ['1.23 IDR', 'CAD'], ['10.00 AUD', 'AUD']);
  my @invalid = (['20.12 ZZZ', 'GBP']);

  module_check('YahooJSON', \@valid, \@invalid);
};

# Check Failover
subtest 'Failover' => sub {
  if ( not $ENV{TEST_FIXER_API_KEY} ) {
    plan skip_all =>
        'Set $ENV{TEST_FIXER_API_KEY} to run this test; get one at https://fixer.io';
  }

  plan tests => 2;

  my $q = Finance::Quote->new('currency_rates' => {order => ['ECB', 'Fixer'],
                                                   fixer => {API_KEY => $ENV{TEST_FIXER_API_KEY}}});
  ok($q);

  my ($from, $to) = ('1000 KZT', 'JPY');
  my $v = $q->currency($from, $to);
  ok(looks_like_number($v), "$from -> $to = $v");
};
  
