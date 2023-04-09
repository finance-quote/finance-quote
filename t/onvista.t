#!/usr/bin/perl -w

use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{'ONLINE_TEST'}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

my $q        = Finance::Quote->new('OnVista');
my @valid    = qw/MRK AAPL SAP/;
my @invalid  = qw/BOGUS/;
my @symbols  = (@valid, @invalid);
my $year     = (localtime())[5] + 1900;
my $lastyear = $year - 1;

plan tests => 1 + 7*@valid + @invalid;

my %quotes = $q->onvista(@symbols);
ok(%quotes);

foreach my $symbol (@valid) {
    ok($quotes{$symbol, 'success'}, "$symbol success");
    ok(defined $quotes{$symbol, 'name'}, "$symbol returned name as $quotes{$symbol, 'name'}");
    ok(defined $quotes{$symbol, 'currency'}, "$symbol returned currency as $quotes{$symbol, 'currency'}");
    ok(defined $quotes{$symbol, 'method'}, "$symbol returned method as $quotes{$symbol, 'method'}");
    ok(defined $quotes{$symbol, 'exchange'}, "$symbol returned exchange as $quotes{$symbol, 'exchange'}");
    ok(defined $quotes{$symbol, 'time'}, "$symbol returned time as $quotes{$symbol, 'time'}");
    ok((substr($quotes{$symbol, 'isodate'}, 0, 4) == $year or
        substr($quotes{$symbol, 'isodate'}, 0, 4) == $lastyear), "$symbol returned isodate as $quotes{$symbol, 'isodate'}");
}

foreach my $symbol (@invalid) {
  ok((not $quotes{'BOGUS', 'success'}), 'failed as expected');
}
