#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Finance::Quote qw/asx/;

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

my ($name, $date, $last, $p_change, $high, $low, $volume, $close);

format STDOUT_TOP =

                                 STOCK REPORT

TICKER         DATE      LAST  %CHANGE       HIGH      LOW    VOLUME     CLOSE
-------------------------------------------------------------------------------
.

format STDOUT =
 @<<<   @>>>>>>>>>>  @###.### @###.###   @###.### @###.### @>>>>>>>>  @###.###
$name,  $date,       $last,   $p_change, $high,   $low,    $volume,   $close
.

foreach my $code (@ARGV) {
	my %quote = asx($code);
	$name = $quote{$code,'name'};
	$date = $quote{$code,'date'};
	$last = $quote{$code,'last'};
	$p_change = $quote{$code,'p_change'};
	$high = $quote{$code,'high'};
	$low = $quote{$code,'low'};
	$volume = $quote{$code,'volume'};
	$close = $quote{$code,'close'};
	write;
}
