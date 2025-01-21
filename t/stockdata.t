#!/usr/bin/perl -w
# vi: set ts=2 sw=2 noai ic showmode showmatch:  

use strict;
use warnings;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

if ( not $ENV{"TEST_STOCKDATA_API_KEY"} ) {
    plan skip_all => 'Set $ENV{"TEST_STOCKDATA_API_KEY"} to run this test';
}

my @valid = qw/CSCO F GE SWAV WM/;
my @invalid = ('BUGUS');

my $q = Finance::Quote->new('StockData', timeout => 30);

my %check    = (
                'currency'  => sub { $_[0] =~ /^[A-Z]+$/ },
                'date'      => sub { $_[0] =~ m{^[0-9]{2}/[0-9]{2}/[0-9]{4}$} },
                'isodate'   => sub { $_[0] =~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/ },
                'last'      => sub { $_[0] =~ /^[0-9.]+$/ },
                'method'    => sub { $_[0] =~ /^stockdata$/ },
                'success'   => sub { $_[0] },
                'symbol'    => sub { $_[0] eq $_[1] },
               );

plan tests => 1 + %check*@valid + @invalid;

my %quotes = $q->fetch('stockdata', @valid);
ok(%quotes);

### [<now>] quotes: %quotes

foreach my $symbol (@valid) {
  while (my ($key, $lambda) = each %check) {
    ok($lambda->($quotes{$symbol, $key}, $symbol), "$key -> $quotes{$symbol, $key}");
  }
}
    
foreach my $symbol (@invalid) {
  ok((not $quotes{'BOGUS', 'success'}), 'failed as expected');
}

