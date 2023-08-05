#!/usr/bin/perl -w
# vi: set ts=2 sw=2 noai ic showmode showmatch: 

use strict;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

my $q        = Finance::Quote->new('Stooq', timeout => 30);
my @valid    = ('DNP', 'ISLN.UK', 'LRQ', 'GBP.UK', 'GBPG.UK');
my @invalid  = qw/BOGUS/;
my @symbols  = (@valid, @invalid);
my $year     = (localtime())[5] + 1900;
my $lastyear = $year - 1;
my %check    = (
                'currency'  => sub { $_[0] =~ /^[A-Z]+$/ },
                'date'      => sub { $_[0] =~ m{^[0-9]{2}/[0-9]{2}/[0-9]{4}$} },
                'isodate'   => sub { $_[0] =~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/ },
                'last'      => sub { $_[0] =~ /^[0-9.]+$/ },
                'method'    => sub { $_[0] =~ /^stooq$/ },
                'success'   => sub { $_[0] },
                'symbol'    => sub { $_[0] eq $_[1] },
               );

plan tests => 1 + %check*@valid + @invalid;

my %quotes = $q->fetch('stooq', @symbols);
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

