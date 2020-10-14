#!/usr/bin/perl -w

use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{'ONLINE_TEST'}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

my $q        = Finance::Quote->new('Bloomberg');
my @valid    = qw/MSFT:US AMZN:US AAPL:US GOOGL:US FB:US/;
my @invalid  = qw/BOGUS/;
my @symbols  = (@valid, @invalid);
my $year     = (localtime())[5] + 1900;
my $lastyear = $year - 1;

plan tests => 1 + 4*@valid + @invalid;

my %quotes = $q->bloomberg(@symbols);
ok(%quotes);

foreach my $symbol (@valid) {
    ok($quotes{$symbol, 'success'}, "$symbol success");
    ok($quotes{$symbol, 'symbol'} eq $symbol, "$symbol defined");
    ok($quotes{$symbol, 'last'} > 0, "$symbol returned last as $quotes{$symbol, 'last'}");
    ok((substr($quotes{$symbol, 'isodate'}, 0, 4) == $year or
        substr($quotes{$symbol, 'isodate'}, 0, 4) == $lastyear), "$symbol returned isodate as $quotes{$symbol, 'isodate'}");
}

foreach my $symbol (@invalid) {
  ok((not $quotes{'BOGUS', 'success'}), 'failed as expected');
}
