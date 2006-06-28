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

package Finance::Quote::Yahoo::Brasil;
require 5.005;

use strict;
use HTTP::Request::Common;
use LWP::UserAgent;
use Finance::Quote::Yahoo::Base qw/yahoo_request base_yahoo_labels/;

use vars qw/$VERSION $YAHOO_BRASIL_URL/;

$VERSION = '1.00';

# URLs of where to obtain information.

$YAHOO_BRASIL_URL = ("http://br.finance.yahoo.com/d/quotes.csv");

sub methods {return (brasil       => \&yahoo_brasil,
		     yahoo_brasil => \&yahoo_brasil)};

{
	my @labels = (base_yahoo_labels());

	sub labels { return (brasil		=> \@labels,
			     yahoo_brasil	=> \@labels); }
}

sub yahoo_brasil
{
	my $quoter = shift;
	my @symbols = @_;
	return unless @symbols;	# Nothing if no symbols.

	# This does all the hard work.
	my %info = yahoo_request($quoter,$YAHOO_BRASIL_URL,\@symbols,".SA", 0);

	foreach my $symbol (@symbols) {
		next unless $info{$symbol,"success"};
		$info{$symbol,"exchange"} = "Bovespa";
		$info{$symbol,"method"} = "yahoo_brasil";
	}
	return %info if wantarray;
	return \%info;
}

1;

=head1 NAME

Finance::Quote::Yahoo::Brasil - Fetch Brasiln stock quotes via Yahoo.

=head1 SYNOPSIS

    use Finance::Quote;
    my $q = Finance::Quote->new;

    my %info = $q->fetch("yahoo_brasil","BHP"); # Use this module only.
    my %info = $q->fetch("brasil","BHP"); # Failover with other methods.

=head1 DESCRIPTION

This module allows information to be fetched from Yahoo abouts stocks
traded on the Brasilian Stock Exchange.

This module is loaded by default on a Finance::Quote object, although
it can be explicitly loaded by passing the argument "Yahoo::Brasil"
to Finance::Quote->new().

This module provides both the "brasil" and "yahoo_brasil" fetch
methods.  You should use the "brasil" method if you wish to allow
failovers to other sources, and "yahoo_brasil" if you only want
to obtain quotes from this module.

Information obtained via this module is governed by Yahoo's terms
and conditions, see http://br.finance.yahoo.com/ for more details.

=head1 LABELS RETURNED

This module returns all the standard labels (where available)
provided by Yahoo, as well as the currency label.  See
Finance::Quote::Yahoo::Base for more information.

=head1 SEE ALSO

Yahoo Brasil, http://br.finance.yahoo.com/

Finance::Quote::Yahoo::Base

=cut
