#!/usr/bin/perl -w
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@Acpan.org>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#    Copyright (C) 2001, Leigh Wedding <leigh.wedding@telstra.com>
#    Copyright (C) 2003, Ian Dall <ian@beware.dropbear.id.au>
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
# but extends its capabilites to additional data sources.
#
# This code was developed as part of GnuCash <http://www.gnucash.org/>

require 5.005;

use strict;

package Finance::Quote::Platinum;

use HTTP::Request::Common;
use LWP::UserAgent;
use HTML::TableExtract;

use vars qw/$PLATINUM_URL $VERSION/;

$VERSION = "0.1";

$PLATINUM_URL = 'http://www.platinum.com.au/Platinum_Trust_Unit_Prices.htm';

sub methods {return (platinum => \&platinum)}

{
	my @labels = qw/name last bid ask date isodate currency/;

	sub labels { return (platinum       => \@labels); }
}

# Platinum Asset Management (Platinum)
# Platinum provides free delayed quotes through their webpage.
#

sub platinum {
	my $quoter = shift;
	my @stocks = @_;
	return unless @stocks;
	my %info;

	my $ua = $quoter->user_agent;

	my $response = $ua->request(GET $PLATINUM_URL);

	unless ($response->is_success) {
		foreach my $stock (@stocks) {
			$info{$stock,"success"} = 0;
			$info{$stock,"errormsg"} = "HTTP session failed";
		}
		return wantarray() ? %info : \%info;
	}

	my $te = HTML::TableExtract->new(
		headers => ["product", "date", "entry", "exit"]);

	$te->parse($response->content);

	# Extract table contents.
	my @rows;
	unless (@rows = $te->rows) {
		foreach my $stock (@stocks) {
			$info{$stock,"success"} = 0;
			$info{$stock,"errormsg"} = "Failed to parse HTML table.";
		}
		return wantarray() ? %info : \%info;
	}

	# Pack the resulting data into our structure.
	foreach my $row (@rows) {
	    	my $name = shift(@$row);
		next if !defined($name);
		# Map between Names and APIR codes
		my %map = ('Platinum European Fund' => 'PLA0001AU',
			   'Platinum International Fund' => 'PLA0002AU',
			   'Platinum Japan Fund' => 'PLA0003AU',
			   'Platinum Asia Fund' => 'PLA0004AU',
			   'Platinum International Brands Fund' => 'PLA0100AU',
			   'Platinum International Technology Fund' => 'PLA0101AU');
			       
		# Delete spaces and '*' which sometimes appears after the code.
		# Also delete high bit characters.
		$name =~ tr/ \000-\037\200-\377/ /s;
		$name =~ s/^ *//;
		$name =~ s/ *$//;
		my $stock = $map{$name};
		if (! $stock) { next};
		$info{$stock,'symbol'} = $stock;
		$info{$stock,'name'} = $name;

		foreach my $label (qw/date ask bid/) {
			$info{$stock,$label} = shift(@$row);
			# Again, get rid of nasty high-bit characters.
			$info{$stock,$label} =~ tr/ \200-\377//d 
				unless ($label eq "name");
		}
		
		$info{$stock,'last'} = $info{$stock,'bid'};

		$quoter->store_date(\%info, $stock, {eurodate => $info{$stock,'date'}});
		$info{$stock, "currency"} = "AUD";
		$info{$stock, "method"} = "platinum";
		$info{$stock, "exchange"} = "Platinum Asset Management";
		$info{$stock, "price"} = $info{$stock,"last"};
		$info{$stock, "success"} = 1;
	}

	# All done.

	return %info if wantarray;
	return \%info;
}

1;

=head1 NAME

Finance::Quote::Platinum	- Obtain quotes from the Platinum Asset Management.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %stockinfo = $q->fetch("platinum","BHP");	   # Only query Platinum.

=head1 DESCRIPTION

This module obtains information from the Platinum Asset Management
http://www.platinum.com.au/docs/pricing.htm.

This module is loaded by default on a Finance::Quote object.  It's
also possible to load it explicity by placing "Platinum" in the argument
list to Finance::Quote->new().

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::Platinum:
name, date, bid, ask, last, currency
and price.

=head1 SEE ALSO

Platinum Asset Management, http://www.platinum.com.au/docs/pricing.htm

Finance::Quote::Yahoo::Australia.

=cut
