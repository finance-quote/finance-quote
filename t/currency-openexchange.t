#!/usr/bin/perl -w

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

plan tests => 1;

subtest 'OpenExchange' => sub {
  if ( not $ENV{TEST_OPENEXCHANGE_API_KEY} ) {
    plan skip_all =>
        'Set $ENV{TEST_OPENEXCHANGE_API_KEY} to run this test; get one at https://openexchangerates.org';
  }

  my @valid   = (['100.00 USD', 'EUR'], ['1.00 GBP', 'IDR'], ['1.23 IDR', 'CAD'], ['10.00 AUD', 'AUD']);
  my @invalid = (['20.12 ZZZ', 'GBP']);

  module_check('OpenExchange', \@valid, \@invalid, {cache => 1, API_KEY => $ENV{TEST_OPENEXCHANGE_API_KEY}});
};
  
