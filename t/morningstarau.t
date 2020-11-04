#!/usr/bin/perl -w

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, Smart::Comments;

use strict;
use warnings;
use Scalar::Util qw(looks_like_number);
use Finance::Quote;
use Test::More;
use Time::Piece;
use feature 'say';

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 30;

my $now = localtime;;
my $a_year_ago = $now->add_years(-1);

my %valid_funds = (
        'BFL0002AU' => 'Bennelong Concentrated Australian Eq',
        'IML0004AU' => 'Investors Mutual All Industrials Share',
        'FID0021AU' => 'Fidelity Australian Opportunities',
    );
my $invalid_fund = 'BOGUS';
my @all_funds = (keys %valid_funds, $invalid_fund);

# Invoke test subject
my $q = Finance::Quote->new();
my %quotes = $q->morningstarau(@all_funds);
ok(%quotes);

### Quotes: %quotes

# Check the valid funds
foreach my $symbol (keys %valid_funds) {
    my $fund_name = $valid_funds{$symbol};
    say "Testing $symbol with name '${fund_name}'";

    ok($quotes{$symbol,'currency'} eq 'AUD');
    my $date = Time::Piece->strptime(($quotes{$symbol,"date"},'%m/%d/%Y'));
    ok($date >= $a_year_ago);
    is($quotes{$symbol,'errormsg'}, undef);
    my $isodate = Time::Piece->strptime(($quotes{$symbol,"isodate"},'%Y-%m-%d'));
    ok($isodate >= $a_year_ago);
    ok($quotes{$symbol,'name'} eq $fund_name);
    ok($quotes{$symbol,'symbol'} eq $symbol);
    ok($quotes{$symbol,'method'} eq 'morningstarau');
    my $price = $quotes{$symbol,'price'} ;
    ok(looks_like_number($price) && $price > 0);
    ok($quotes{$symbol,'success'});
}

# Check that an invalid fund returns failure:
ok(!$quotes{$invalid_fund,"success"});
ok($quotes{$invalid_fund,"errormsg"} ne '');
