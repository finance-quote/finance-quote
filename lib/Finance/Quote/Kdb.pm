#!/usr/bin/perl -w

#  Kdb.pm

package Finance::Quote::Kdb;
require 5.004;

use strict;
use POSIX qw(strftime);
use Encode 'from_to';

use vars qw($VERSION $KDB_URL);

use LWP::UserAgent;
use HTTP::Request::Common;

$VERSION = '0.1';

# URLs of where to obtain information.

$KDB_URL =
("http://k-db.com/site/jikeiretsu.aspx?hyouji=&download=csv&c=");


sub methods { return (kdb => \&kdb); }

{
    my @labels = qw/name price currency date/;
    sub labels { return (kdb => \@labels) }
}

#
# =======================================================================

sub kdb   {
    my $quoter = shift;
    my @symbols = @_;

    # Make sure symbols are requested
    ##CAN exit more gracefully - add later##

    return unless @symbols;

    # Local Variables
    my(%fundquote, $code);

    my $ua = $quoter->user_agent;

    foreach (@symbols) {

	my $code = $_;
	my $url = "$KDB_URL$code";
	my $reply = $ua->request(GET $url);

	return unless ($reply->is_success);
	my @rows = split('\015?\012', $reply->content);

	my @q = $quoter->parse_csv($rows[0]);
	my $name = $q[2];
	from_to($name, 'shift-jis', 'utf-8');
	@q = $quoter->parse_csv($rows[2]);

	$fundquote {$code, "symbol"} = $code;
	$fundquote {$code, "price"} = $q[4];
	$fundquote {$code, "name"} = $name;
	$fundquote {$code, "date"} =   $q[0];
	$fundquote {$code, "currency"} = "JPY";

	$fundquote {$code, "method"} = "Kdb";
	
	# Assume things are fine here.
	$fundquote {$code, "success"} = 1;
    } #end symbols

    return %fundquote if wantarray;
    return \%fundquote;
}

1;

=head1 NAME

Finance::Quote::Kdb - Obtain Japanese stock prices from
k-db.com

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %kinfo = $q->fetch("kdb","1306"); 

=head1 DESCRIPTION

This module obtains information about Japanese stock prices from
L<http://k-db.com/>.

=head1 FUNDLIB-CODE

..

=head1 LABELS RETURNED

The following labels may be retruned by Finance::Quote::Kdb:
symbol, price, name,date, currency.

=head1 SEE ALSO

Kdb website - L<http://k-db.com/>

=head1 AUTHOR

TANIGUCHI Takaki 

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013, TANIGUCHI Takaki <takaki@asis.media-as.org>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 2 of the License, or
(at your option) any later version.

=cut
