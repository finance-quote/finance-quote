#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Finance::Quote;

# This script demonstrates how currencies can be converted using
# Finance::Quote.  At the moment the currency function is under
# development.  If you use it, you should expect its syntax and
# semantics to change.

# Example usage:   currency-lookup.pl USD AUD
# (Converts from US Dollars to Australian Dollars)

die "Usage: $0 FROM TO\n" unless defined($ARGV[1]);

my $q = Finance::Quote->new();

my %hash = $q->currency($ARGV[0],$ARGV[1]);

die "Urgh!  Nothing back\n" unless defined(%hash);

print $hash{from}."->".$hash{to}." = ".$hash{exchange}."\n";
