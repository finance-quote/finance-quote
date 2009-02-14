#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 12;

# Test overall currency lookup
my $currencies = Finance::Quote::currency_lookup();

my %test_currencies = ( AUD => "Australian Dollar"
                      , EUR => "Euro"
                      , CAD => "Canadian Dollar"
                      );

while ( my ($code, $name) = each %test_currencies ) {
  ok( exists $currencies->{$code}, "Expected currency code (${code}) exists" );
  is( $currencies->{$code}->{name}
    , $name
    , "Expected currency name (${name}) for code (${code})"
    );
}

# Test selective currency lookup
$currencies = Finance::Quote::currency_lookup( name => qr/pound/i );

# Test multiple lookup parameters
$currencies = Finance::Quote::currency_lookup( name => "Australia"
                                             , code => qr/AU/ );
ok( exists $currencies->{AUD}
  , "Expected currency code (AUD) exists for matching multiple params" );
cmp_ok( scalar keys %{$currencies}, '==', 1
      , "Only one currency returned for matching multiple params"
      );

$currencies = Finance::Quote::currency_lookup( name => "Euro"
                                             , code => "AUD" );
cmp_ok( scalar keys %{$currencies}, '==', 0
      , "Expected zero-response for non-matching multiple params"
      );

# Test non-matching currency lookup
$currencies = Finance::Quote::currency_lookup( name => qr/rubbish_value/i );
is( ref $currencies
  , 'HASH'
  , 'Hash-ref returned for non-matching lookup'
  );
cmp_ok( scalar keys %{$currencies}
      , '==', 0
      , "Empty hashref returned for non-matching lookup"
      );

# Test that an error returns undef
$currencies = Finance::Quote::currency_lookup( invalid_param => 1 );
is( $currencies
  , undef
  , "Error results in undef response"
  );
