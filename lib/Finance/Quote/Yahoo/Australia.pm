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

package Finance::Quote::Yahoo::Australia;
require 5.004;

use strict;
use HTTP::Request::Common;
use LWP::UserAgent;
use Finance::Quote::Yahoo::Base qw/yahoo_request base_yahoo_labels/;

use vars qw/$VERSION $YAHOO_AUSTRALIA_URL/;

$VERSION = '0.19';

# URLs of where to obtain information.

$YAHOO_AUSTRALIA_URL = ("http://au.finance.yahoo.com/d/quotes.csv");

sub methods {return (australia       => \&yahoo_australia,
		     yahoo_australia => \&yahoo_australia)};

{
	my @labels = (base_yahoo_labels(),"currency");

	sub labels { return (australia		=> \@labels,
			     yahoo_australia	=> \@labels); }
}

sub yahoo_australia
{
	my $quoter = shift;
	my @symbols = @_;
	return unless @symbols;	# Nothing if no symbols.

	# Yahoo Australia needs AX. appended to indicate that we're
	# dealing with Australian stocks.

	# This does all the hard work.
	my %info = yahoo_request($quoter,$YAHOO_AUSTRALIA_URL,\@symbols,".AX");

	foreach my $symbol (@symbols) {
		next unless $info{$symbol,"success"};
		$info{$symbol,"currency"} = "AUD";
	}
	return %info if wantarray;
	return \%info;
}
