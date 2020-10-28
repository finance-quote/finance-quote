#!/usr/bin/perl -w

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, Smart::Comments;

use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

my $q        = Finance::Quote->new();
my @valid    = ('LU0804734787');
my @invalid  = qw/BOGUS/;
my @symbols  = (@valid, @invalid);
my $year     = (localtime())[5] + 1900;
my %check    = (
                'currency'   => sub { $_[0] =~ /^[A-Z]+$/ },
                'date'       => sub { $_[0] =~ m{^[0-9]{2}/[0-9]{2}/([0-9]{4})$} and ($1 == $year || $1 == $year + 1) },
                'isin'       => sub { $_[0] =~ /^[A-Z]{2}[0-9]{10}$/ },
                'isodate'    => sub { $_[0] =~ /^([0-9]{4})-[0-9]{2}-[0-9]{2}$/ and ($1 == $year || $1 == $year + 1) },
                'last'       => sub { $_[0] =~ /^[0-9.]+$/ },
                'method'     => sub { $_[0] =~ /^fondsweb$/ },
                'name'       => sub { length($_[0]) },
                'nav'        => sub { $_[0] =~ /^[0-9.]+$/ },
                'success'    => sub { $_[0] },
                'type'       => sub { $_[0] eq 'fund' },
                'year_range' => sub { $_[0] =~ /^[0-9.]+\s*-\s*[0-9.]+$/ },
                );

plan tests => 1 + %check*@valid + @invalid;

my %quotes = $q->fetch('fondsweb', @symbols);
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

