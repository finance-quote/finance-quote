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
#
# This code derived from Padzensky's work on package Finance::YahooQuote,
# but extends its capabilites to encompas a greater number of data sources.
#
# This code was developed as part of GnuCash <http://www.gnucash.org/>

package Finance::Quote::Yahoo::Europe;
require 5.004;

use strict;
use HTTP::Request::Common;
use LWP::UserAgent;
use Finance::Quote::Yahoo::Base qw/yahoo_request base_yahoo_labels/;

use vars qw($VERSION $YAHOO_EUROPE_URL);

$VERSION = '0.19';

# URLs of where to obtain information.

$YAHOO_EUROPE_URL = ("http://finance.uk.yahoo.com/d/quotes.csv");

sub methods {return (europe => \&yahoo_europe,yahoo_europe => \&yahoo_europe)};

{
	my @labels = (base_yahoo_labels(),"currency");

	sub labels { return (europe => \@labels, yahoo_europe => \@labels); }
}

# =======================================================================
# yahoo_europe gets quotes for European markets from Yahoo.
sub yahoo_europe
{
	my $quoter = shift;
	my @symbols = @_;
	return unless @symbols;	# Nothing if no symbols.

	# This does all the hard work.
	my %info = yahoo_request($quoter,$YAHOO_EUROPE_URL,@symbols);

	foreach my $symbol (@symbols) {
		if ($info{$symbol,"success"}) {
			$info{$symbol,"currency"} = "EUR";
		}
	}

	return %info if wantarray;
	return \%info;
}
