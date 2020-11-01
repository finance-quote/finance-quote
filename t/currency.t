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

plan tests => 4;

# Check that FQ fails on bogus CurrencyRates method
my $q = Finance::Quote->new('currency_rates' => {order => ['DoesNotExist']});
ok(not $q);

# Check AlphaVantage
subtest 'AlphaVantage' => sub {
  if ( not $ENV{TEST_ALPHAVANTAGE_API_KEY} ) {
    plan skip_all =>
        'Set $ENV{TEST_ALPHAVANTAGE_API_KEY} to run this test; get one at https://www.alphavantage.co';
  }

  plan tests => 1;

  my $q = Finance::Quote->new('currency_rates' => {order => ['AlphaVantage'],
                                                   alphavantage => {API_KEY => $ENV{TEST_ALPHAVANTAGE_API_KEY}}
                                                  });
  ok($q);

  $q->currency( "100.00 USD", "EUR");
  $q->currency( "20000 IDR", "EUR");
};
  
# Check ECB
subtest 'ECB' => sub {
  my @valid   = (['100.00 USD', 'EUR'], ['1.00 GBP', 'IDR'], ['20000.00 IDR', 'CAD']);
  my @invalid = (['20.12 ZZZ', 'GBP']);

  plan tests => 1 + @valid + @invalid;

  my $q = Finance::Quote->new('currency_rates' => {order => ['ECB']});
  ok($q);

  foreach my $test (@valid) {
    my ($from, $to) = @{$test};
    my $v = $q->currency($from, $to);
    ok(looks_like_number($v), "$from -> $to = $v");
  }

  foreach my $test (@invalid) {
    my ($from, $to) = @{$test};
    my $v = $q->currency($from, $to);
    is($v, undef, "$from -> $to failed as expected");
  }
};

# Check Fixer
subtest 'Fixer' => sub {
  if ( not $ENV{TEST_FIXER_API_KEY} ) {
    plan skip_all =>
        'Set $ENV{TEST_FIXER_API_KEY} to run this test; get one at https://fixer.io';
  }

  plan tests => 1;

  my $q = Finance::Quote->new('currency_rates' => {order => ['Fixer'],
                                                   fixer => {API_KEY => $ENV{TEST_FIXER_API_KEY}}
                                                  });
  ok($q);
};
  


# # Explicit conversion...
# ok($q->currency("USD","AUD"));			# Test 1
# ok($q->currency("EUR","JPY"));			# Test 2
# ok(! defined($q->currency("XXX","YYY")));	# Test 3
# 
# # test for thousands : GBP -> IQD. This should be > 1000
# ok($q->currency("GBP","IQD")>1000) ;            # Test 4
# 
# # Test 5
# ok(($q->currency("10 AUD","AUD")) == (10 * ($q->currency("AUD","AUD"))));
# 
# # Euros into French Francs are fixed at a conversion rate of
# # 1:6.559576 .  We can use this knowledge to test that a stock is
# # converting correctly.
# 
# # Test 6
# my %baseinfo = $q->fetch("alphavantage","BA.L");
# ok($baseinfo{"BA.L","success"});
# 
# $q->set_currency("AUD");	# All new requests in Aussie Dollars.
# 
# my %info = $q->fetch("alphavantage","BA.L");
# ok($info{"BA.L","success"});		# Test 7
# ok($info{"BA.L","currency"} eq "AUD");	# Test 8
# ok($info{"BA.L","last"} > 0);		# Test 9
# 
# # Check if inverse is working ok
# ok(check_inverse("EUR","RUB"),"Inverse is calculated correctly: multiplication should be 1");
# ok(check_inverse("CZK","USD"),"Inverse is calculated correctly: multiplication should be 1");
# 
# sub check_inverse {
#     my ($cur1,$cur2)=@_;
#     my $a = $q->currency($cur1,$cur2);
#     my $b = $q->currency($cur2,$cur1);
#     return $a*$b;
# }
