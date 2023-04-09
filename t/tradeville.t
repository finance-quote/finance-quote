#!/usr/bin/perl -w

use strict;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

my $q        = Finance::Quote->new();
my @valid    = ('TLV', 'BRD', 'SNP');
my @invalid  = qw/BOGUS/;
my @symbols  = (@valid, @invalid);
my $year     = (localtime())[5] + 1900;
my $lastyear = $year - 1;
my %check    = (
                'cap'       => sub { $_[0] =~ /^[0-9,]+$/ },
                'currency'  => sub { $_[0] =~ /^[A-Z]+$/ },
                'date'      => sub { $_[0] =~ m{^[0-9]{2}/[0-9]{2}/[0-9]{4}$} },
                'day_range' => sub { $_[0] =~ m{^[0-9.]+/[0-9.]+$} },
                'div_yield' => sub { $_[0] =~ m{^(-?[0-9.]+%)|(n/a)$} },
                'exchange'  => sub { $_[0] =~ /^[A-Za-z]+$/ },
                'isodate'   => sub { $_[0] =~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/ },
                'last'      => sub { $_[0] =~ /^[0-9.]+$/ },
                'method'    => sub { $_[0] =~ /^tradeville$/ },
                'open'      => sub { $_[0] =~ /^[0-9.]+$/ },
                'p_change'  => sub { $_[0] =~ /^-?[0-9.]+%$/ },
                'success'   => sub { $_[0] },
                'symbol'    => sub { $_[0] eq $_[1] },
                'volume'    => sub { $_[0] =~ /^[0-9,]+$/ },
               );

plan tests => 1 + %check*@valid + @invalid;

my %quotes = $q->fetch('tradeville', @symbols);
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

