#!/usr/bin/perl -w
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@cpan.org>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#    Copyright (C) 2001, Leigh Wedding <leigh.wedding@telstra.com>
#    Copyright (C) 2006, Mika Laari <mika.laari@iki.fi>
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

require 5.005;

use strict;

package Finance::Quote::HEX;

use HTTP::Request::Common;
use LWP::UserAgent;
use HTML::TableExtract;

use vars qw/$HEX_URL $VERSION/;

$VERSION = "1.0";

$HEX_URL = 'http://omxgroup.is-teledata.com/html/securitypricelistequities.html?language=fi';

# XXX Europe should probably be removed since this module provides only
# the Finnish quotes.
sub methods {return ('europe' => \&hex, 'finland' => \&hex,'hex' => \&hex)}

{
	my @labels = qw/name last high low date isodate time p_change volume bid ask
	                price method exchange/;

	sub labels { return ('europe'  => \@labels,
	                     'finland' => \@labels,
	                     'hex'     => \@labels); }
}

# Helsinki Stock Exchange (HEX)
# The HEX provides free delayed quotes through their webpage.
# This module is heavily based on the ASX.pm.
#
# Maintainer of this section is Mika Laari <laari@iki.fi>.

sub hex {
	my $quoter = shift;
	my @stocks = @_;
	return unless @stocks;
	my %info;

	my $ua = $quoter->user_agent;
	my $url = $HEX_URL;

	my $response = $ua->request(GET $url);

	unless ($response->is_success) {
		foreach my $stock (@stocks) {
			$info{$stock,"success"} = 0;
			$info{$stock,"errormsg"} = "HTTP session failed";
		}
		return wantarray() ? %info : \%info;
	}

	# Get a table containing information for all the stocks.

	my $te = HTML::TableExtract->new();

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

	# Prepare an array for checking whether a symbol is among the wanted ones.
	my %is_stock = ();
	for (@stocks) { $is_stock{uc($_)} = 1 }

	# Pack the resulting data into our structure.
	foreach my $row (@rows) {

		my $stock = $$row[1];
		next unless $stock;

		# Delete spaces and high bit characters.
		$stock =~ tr/ \200-\377//d;

		next unless $is_stock{$stock};

		$info{$stock,'symbol'} = $stock;


		$info{$stock,'name'} = $$row[0];
		$info{$stock,'name'} =~ s/^\s*(.*?)\s*$/$1/;

		$info{$stock,'p_change'} = $$row[3];
		# Remove possible plus and other unnecessary characters.
		$info{$stock,'p_change'} =~ s/\+?(-?\d+,\d+)%/$1/;

		$info{$stock,'bid'} = $$row[4];
		$info{$stock,'ask'} = $$row[5];
		$info{$stock,'high'} = $$row[6];
		$info{$stock,'low'} = $$row[7];

		$info{$stock,'last'} = $$row[8];
		# Again, get rid of nasty high-bit characters.
		#$info{$stock,'last'} =~ tr/ \200-\377//d;

		$info{$stock,'volume'} = $$row[9];
		$info{$stock,'volume'} =~ tr/ \200-\377//d;
		
		# Use deciman point instead of comma.
		foreach my $label (qw/last bid ask high low p_change/) {
			$info{$stock,$label} =~ s/,/./;
		}


		$info{$stock, "currency"} = "EUR";
		$quoter->store_date(\%info, $stock, {today => 1});
#		$info{$stock, "time"} = $time;
		$info{$stock, "method"} = "hex";
		$info{$stock, "exchange"} = "Helsinki Stock Exchange";
		$info{$stock, "price"} = $info{$stock,"last"};
		$info{$stock, "success"} = 1;
	}

	# All done.

	return %info if wantarray;
	return \%info;
}

1;

=head1 NAME

Finance::Quote::HEX	- Obtain quotes from the Helsinki Stock Exchange.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %stockinfo = $q->fetch("hex","NOK1V");	   # Only query ASX.
    %stockinfo = $q->fetch("finland","NOK1V"); # Failover to other sources OK.

=head1 DESCRIPTION

This module obtains information from the Helsinki Stock Exchange
http://www.hex.com/.  All Finnish stocks are available.

This module is not loaded by default on a Finance::Quote object.
It's possible to load it explicity by placing "HEX" in the argument
list to Finance::Quote->new().

This module provides both the "hex" and "finland" fetch methods.
Please use the "finland" fetch method if you wish to have failover
with other sources for Finnish stocks.  Using the "hex" method will
guarantee that your information only comes from the Helsinki Stock
Exchange.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::HEX:
name, last, high, low, date, time, p_change, volume, bid, ask,
price, method and exchange.

=head1 SEE ALSO

Helsinki Stock Exchange, http://www.hex.com/

=cut
