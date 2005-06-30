#!/usr/bin/perl -w
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@cpan.org>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
#    02111-1307, USA
#
#    This code gratefully based on the existing
#    Finance::Quote::Yahoo::Australia

package Finance::Quote::Yahoo::NZ;
require 5.005;

use strict;
use HTTP::Request::Common;
use LWP::UserAgent;
use Finance::Quote::Yahoo::Base qw/yahoo_request base_yahoo_labels/;

use vars qw/$VERSION $YAHOO_NZ_URL/;

$VERSION = '1.00';

# URLs of where to obtain information.

$YAHOO_NZ_URL = ("http://au.finance.yahoo.com/d/quotes.csv");

sub methods {return (nz => \&yahoo_nz, yahoo_nz => \&yahoo_nz)};

{
	my @labels = (base_yahoo_labels(),"currency","method","exchange");

	sub labels { return (nz => \@labels, yahoo_nz => \@labels); }
}

sub yahoo_nz
{
	my $quoter = shift;
	my @symbols = @_;
	return unless @symbols;	# Nothing if no symbols.

	# Yahoo nz needs NZ appended to indicate that we're
	# dealing with nz stocks.

	# This does all the hard work.
	my %info = yahoo_request($quoter,$YAHOO_NZ_URL,\@symbols,".NZ");

	foreach my $symbol (@symbols) {
		next unless $info{$symbol,"success"};
		$info{$symbol,"exchange"} = "New Zealand Stock Exchange";
		$info{$symbol,"method"} = "yahoo_nz";
	}
	return %info if wantarray;
	return \%info;
}

1;

=head1 NAME

Finance::Quote::Yahoo::nz - Fetch nzn stock quotes via Yahoo.

=head1 SYNOPSIS

    use Finance::Quote;
    my $q = Finance::Quote->new;

    my %info = $q->fetch("yahoo_nz","DPC"); # Use this module only.
    my %info = $q->fetch("nz","DPC"); # Failover with other methods.

=head1 DESCRIPTION

This module allows information to be fetched from Yahoo about stocks
traded on the New Zealand Stock Exchange.  Information about indexes
is not available through this module.

This module is loaded by default on a Finance::Quote object, although
it can be explicitly loaded by passing the argument "Yahoo::nz"
to Finance::Quote->new().

This module provides only the "yahoo_nz" fetch
methods. The author (stephen@vital.org.nz) will write a module to access
the NZX site if asked nicely.

Information obtained via this module is governed by Yahoo's terms
and conditions, see http://au.finance.yahoo.com/ for more details.

=head1 LABELS RETURNED

This module returns all the standard labels (where available)
provided by Yahoo, as well as the currency label.  See
Finance::Quote::Yahoo::Base for more information.

=head1 SEE ALSO

Yahoo Australia, http://au.finance.yahoo.com/

Finance::Quote::Yahoo::Base

=cut
