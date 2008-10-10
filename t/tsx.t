#!/usr/bin/perl -w
use strict;
use Test::More;
use Data::Dumper;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 26 ;

# Test TSX functions.

my $q      = Finance::Quote->new();
my @stocks = ("NT", "BCE", "AER");

my %regexps = (
	NT  => qr/\bNortel\b/,
	BCE => qr/\b(BCE|Bell)\b/,
	AER => qr/\bAeroplan\b/,
);


my %quotes = $q->fetch("tsx", @stocks);
ok(%quotes);

foreach my $stock (@stocks) {

	my $name = $quotes{$stock, "name"};
	print "#Testing $stock: $name\n";

	my $regexp = $regexps{$stock};
	ok($name =~ /$regexp/i);

	ok($quotes{$stock, "exchange"} eq 'T');
	ok($quotes{$stock, "method"} eq 'tsx');

	ok($quotes{$stock, "last"} > 0);
	ok($quotes{$stock, "net"} =~ /^-?\d+\.\d+$/);
	ok($quotes{$stock, "p_change"} =~ /^-?\d+\.\d+$/);
	ok($quotes{$stock, "success"});
	ok($quotes{$stock, "volume"} >= 0);
}


# Check that a bogus stock returns no-success.
%quotes = $q->fetch("tsx", "BOGUS");
ok(! $quotes{"BOGUS","success"});
