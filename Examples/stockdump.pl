#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Finance::Quote;
use Data::Dumper;

# A very very simple script.  Takes a source and a symbol, looks it up,
# and dumps it to STDOUT.  Useful for debugging.

die "Usage: $0 source symbol\n" unless (defined $ARGV[1]);

my $q = Finance::Quote->new;

my %quotes = $q->fetch(@ARGV);

print Dumper(\%quotes);

