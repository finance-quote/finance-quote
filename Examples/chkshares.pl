#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Finance::Quote qw/asx/;
use Data::Dumper;

=head1 NAME

chkshares.pl - Check ASX share information.

=head1 USAGE

chkshares.pl TLS CML ITE

=head1 NOTES

Example program.  Demonstrates how to use one of the interfaces to
Finance::Quote.

In the future this program will be expanded to handle other Finance::Quote
interfaces (eg, yahoo and yahoo_europe).

=cut

foreach my $code (@ARGV) {
	print Dumper(\{asx($code)});
}
