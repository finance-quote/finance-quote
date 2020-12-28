#!/usr/bin/perl -w

use strict;

use Test::More;
use Finance::Quote;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

my $q        = Finance::Quote->new();
my @valid    = ("SEB Auto Hållbar 100", "SEB Life - Ethical Global Index");
my @invalid  = qw/BOGUS/;
my @symbols  = (@valid, @invalid);
my $year     = (localtime())[5] + 1900;
my $lastyear = $year - 1;

plan tests => 1 + 5*@valid + @invalid;

my %quotes = $q->seb_funds(@symbols);
ok(%quotes);

### quotes : %quotes

foreach my $symbol (@valid) {
    ok($quotes{$symbol, 'success'}, "$symbol success");
    ok($quotes{$symbol, 'price'} > 0, "$symbol returned price as $quotes{$symbol, 'price'}");
    ok(defined $quotes{$symbol, 'name'}, "$symbol returned name as $quotes{$symbol, 'name'}");
    ok($quotes{$symbol, 'currency'} eq "SEK", "$symbol returned currency as $quotes{$symbol, 'currency'}");
    ok((substr($quotes{$symbol, 'isodate'}, 0, 4) == $year or
        substr($quotes{$symbol, 'isodate'}, 0, 4) == $lastyear), "$symbol returned isodate as $quotes{$symbol, 'isodate'}");
}

foreach my $symbol (@invalid) {
  ok((not $quotes{'BOGUS', 'success'}), 'failed as expected');
}
