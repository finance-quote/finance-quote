#!/usr/bin/perl -w

use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{'ONLINE_TEST'}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

my $q        = Finance::Quote->new('OnVista');
my @valid    = qw/MRK AAPL SAP FR0010510800 A3GQ2N/;
my @invalid  = qw/BOGUS/;
my @symbols  = (@valid, @invalid);
my @labels   = qw/symbol isin wkn name open close high low last date currency exchange method p_change/;
my $year     = (localtime())[5] + 1900;
my $lastyear = $year - 1;

plan tests => 1 + (3 + @labels) * @valid + @invalid;

my %quotes = $q->onvista(@symbols);
ok(%quotes);

foreach my $symbol (@valid) {
    ok($quotes{$symbol, 'success'}, "$symbol success");
    for my $label (@labels) {
        ok(defined $quotes{$symbol, $label}, "$symbol returned $label as $quotes{$symbol, $label}");
    }
    ok((substr($quotes{$symbol, 'isodate'}, 0, 4) == $year or
        substr($quotes{$symbol, 'isodate'}, 0, 4) == $lastyear), "$symbol returned isodate as $quotes{$symbol, 'isodate'}");
    ok($quotes{$symbol, 'time'} =~ /^[0-2]?[0-9]:[0-5][0-9]/, "$symbol returned time as $quotes{$symbol, 'time'}");
}

foreach my $symbol (@invalid) {
  ok((not $quotes{'BOGUS', 'success'}), 'failed as expected');
}
