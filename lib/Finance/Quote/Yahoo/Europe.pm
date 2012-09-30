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
# This code derived from Padzensky's work on package Finance::YahooQuote,
# but extends its capabilites to encompas a greater number of data sources.
#
# This code was developed as part of GnuCash <http://www.gnucash.org/>

package Finance::Quote::Yahoo::Europe;
require 5.005;

use strict;
use HTTP::Request::Common;
use LWP::UserAgent;
use Finance::Quote::Yahoo::Base qw/yahoo_request base_yahoo_labels/;

use vars qw($VERSION $YAHOO_EUROPE_URL);

$VERSION = '1.18';

# URLs of where to obtain information.

$YAHOO_EUROPE_URL = ("http://uk.finance.yahoo.com/d/quotes.csv");

# Yahoo Europe switched date and time. sending t1d1 or d1t1
# returns the same : Time followed by date. This is a short
# bug fix until yahoo changes back again.
#
# Yahoo Europe doens't return values for r1 (div_date) and q (ex_div)
# Another solution might be to change Base.pm FIELDS labels to this
# string + div_date and ex_div. Code would be nicier, but this will
# need more testing for other yahoo modules and can be done later.
our @YH_EUROPE_FIELDS = qw/symbol name last net p_change volume bid ask
                           close open day_range year_range eps pe div div_yield
                           cap avg_vol currency time date ex_div div_date/;
our @YH_FIELD_ENCODING = qw/s n l1 c1 p2 v b a p o m w e r d y j1 a2 c4 t1 d1 q r1/;

sub methods {return (europe => \&yahoo_europe,yahoo_europe => \&yahoo_europe)};

{
	my @labels = (base_yahoo_labels(),"currency","method");

	sub labels { return (europe => \@labels, yahoo_europe => \@labels); }
}

# =======================================================================
# yahoo_europe gets quotes for European markets from Yahoo.
sub yahoo_europe
{
	my $quoter = shift;
	my @symbols = @_;
	return unless @symbols;	# Nothing if no symbols.

        # localise the Base.FIELDS array. Perl restores the array at
        # the end of this sub.
        local @Finance::Quote::Yahoo::Base::FIELDS = @YH_EUROPE_FIELDS ;
        local @Finance::Quote::Yahoo::Base::FIELD_ENCODING = @YH_FIELD_ENCODING ;

	# This does all the hard work.
	my %info = yahoo_request($quoter,$YAHOO_EUROPE_URL,\@symbols);

	foreach my $symbol (@symbols) {
		next unless $info{$symbol,"success"};
		$info{$symbol,"method"} = "yahoo_europe";
	}

	return %info if wantarray;
	return \%info;
}

1;

=head1 NAME

Finance::Quote::Yahoo::Europe - Fetch quotes from Yahoo Europe

=head1 SYNOPSIS

    use Finance::Quote;
    $q = Finance::Quote->new;

    %info = $q->fetch("europe","UG.PA"); # Failover to other methods ok.
    %info = $q->fetch("yahoo_europe","UG.PA"); # Use this module only.

=head1 DESCRIPTION

This module fetches information from Yahoo Europe.  Symbols should be
provided in the format "SYMBOL.EXCHANGE", where the exchange code is
one of the following:

	PA - Paris
	BC - Barcelona
	BE - Berlin
	BI - Bilbao
	BR - Brussels
	CO - Copenhagen
	D  - Dusseldorf
	F  - Frankfurt
	H  - Hamburg
	HA - Hanover
	L  - London
	MA - Madrid
	MC - Madrid (M.C.)
	MI - Milan
	MU - Munich
	O  - Oslo
	ST - Stockholm
	SG - Stuttgart
	VA - Valence
	VI - Vienna
	DE - Xetra (was FX)

This module provides both the "europe" and "yahoo_europe" methods.
The "europe" method should be used if failover methods are desirable.
The "yahoo_europe" method should be used you desire to only fetch
information from Yahoo Europe.

This module is loaded by default by Finance::Quote, but can be loaded
explicitly by specifying the parameter "Yahoo::Europe" to
Finance::Quote->new().

Information obtained by this module may be covered by Yahoo's terms
and conditions.  See http://finance.uk.yahoo.com/ for more details.

=head1 SPECIFIC NOTES ON CERTAIN SYMBOLS

Starting in November 2010, the Yahoo site didn't respond to ^DJI symbol
retrieval. Use ^DJI.US instead.

=head1 LABELS RETURNED

This module returns all the standard labels (where available) provided
by Yahoo.  See Finance::Quote::Yahoo::Base for a list of these.  The
currency label is also returned.

Note however that div_date and ex_div have been removed by yahoo
europe site

=head1 SEE ALSO

Yahoo Europe, http://finance.uk.yahoo.com/

Finance::Quote::Yahoo::Base

=cut
