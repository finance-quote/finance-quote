#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 26;

# Test BSERO functions.

my $q      = Finance::Quote->new();
my @stocks = ("TLV", "BRD", "SNP");

my %regexps = (
	TLV  => qr/\bTLV\b/,
	BRD => qr/\bBRD\b/,
	SNP => qr/\bSNP\b/,
);


my %quotes = $q->fetch("bsero", @stocks);
ok(%quotes);

foreach my $stock (@stocks) {

	my $name = $quotes{$stock, "name"};
	print "#Testing $stock: $name\n";

	my $regexp = $regexps{$stock};
	ok($name =~ /$regexp/i);

	ok($quotes{$stock, "exchange"} eq 'Bucharest Stock Exchange');
	ok($quotes{$stock, "method"} eq 'bsero');

	ok($quotes{$stock, "last"} > 0);
	ok($quotes{$stock, "open"} =~ /^-?\d+\.\d+$/);
	ok($quotes{$stock, "p_change"} =~ /^-?\d+\.\d+$/);
	ok($quotes{$stock, "success"});
	ok($quotes{$stock, "volume"} >= 0);
}


# Check that a bogus stock returns no-success.
%quotes = $q->fetch("tsx", "BOGUS");
ok(! $quotes{"BOGUS","success"});
