#!/usr/bin/perl -w
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#    Copyright (C) 2001, Leigh Wedding <leigh.wedding@telstra.com>
#    Copyright (C) 2000-2004, Paul Fenwick <pjf@cpan.org>
#    Copyright (C) 2014, Chris Good <chris.good@@ozemail.com.au>
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
use warnings;

package Finance::Quote::ASX;

use HTTP::Request::Common;
use LWP::UserAgent;
use HTML::TableExtract;
use Encode;

use vars qw/$ASX_URL @ASX_SEC_CODES/;

# VERSION

$ASX_URL = 'http://www.asx.com.au/asx/markets/priceLookup.do?by=asxCodes&asxCodes=';

# These are the ASX codes starting with X that are securities not indexes
#  and thus need currency AUD returned
# See http://www.asx.com.au/asx/research/listedCompanies.do
@ASX_SEC_CODES = (qw/XAM XIP XRO XPD XPE XF1 XRF XST XTD XTE XTV/);

sub methods {return (australia => \&asx,asx => \&asx)}

{
	my @labels = qw/last net p_change bid offer high low volume
	                price method exchange/;

	sub labels { return (australia => \@labels,
	                     asx       => \@labels); }
}

# Australian Stock Exchange (ASX)
# The ASX provides free delayed quotes through their webpage.
#
# Maintainer of this section is Paul Fenwick <pjf@cpan.org>
# 5-May-2001 Updated by Leigh Wedding <leigh.wedding@telstra.com>
# 24-Feb-2014 Updated by Chris Good <chris.good@@ozemail.com.au>

sub asx {
	my $quoter = shift;
	my @all_stocks = @_;
	return unless @all_stocks;
	my @stocks;
	my %info;

	my $ua = $quoter->user_agent;

	# ASX webpage only handles up to 10 quote requests at once

	while (@stocks = splice(@all_stocks, 0, 10)) {
		my $response = $ua->request(GET $ASX_URL.join("%20",@stocks));
		unless ($response->is_success) {
			foreach my $stock (@stocks, @all_stocks) {
				$info{$stock,"success"} = 0;
				$info{$stock,"errormsg"} = "HTTP session failed";
			}
			return wantarray() ? %info : \%info;
		}

		my $te = HTML::TableExtract->new(
			automap => 0,
			headers => ["Code", "Last", '\+/-', "% Chg", "Bid",
			    "Offer", "Open", "High", "Low", "Volume"]);

		$te->parse(decode('utf-8',$response->content));

		# Extract table contents.
		my @rows;
		unless (($te->tables > 0) && ( @rows = $te->rows)) {
			foreach my $stock (@stocks, @all_stocks) {
				$info{$stock,"success"} = 0;
				$info{$stock,"errormsg"} = "Failed to parse HTML table.";
			}
			return wantarray() ? %info : \%info;
		}

		# Pack the resulting data into our structure.
		foreach my $row (@rows) {
			my $stock = shift(@$row);

			# Skip any blank lines.
			next unless $stock;

			# Delete spaces and '*' which sometimes appears after the code.
			# Also delete high bit characters.
			$stock =~ tr/* \200-\377//d;

			# Delete any whitespace characters
			$stock =~ s/\s//g;

			$info{$stock,'symbol'} = $stock;

			foreach my $label (qw/last net p_change bid offer open
				      high low volume/) {
				$info{$stock,$label} = shift(@$row);

				# Again, get rid of nasty high-bit characters.
				$info{$stock,$label} =~ tr/ \200-\377//d
					unless ($label eq "name");
			}

			# get rid of trailing whitespace after 'last'
			$info{$stock,'last'} =~ s/\s//g;

			# If that stock does not exist, it will have a empty
			# string for all the fields.  The "last" price should
			# always be defined (even if zero), if we see an empty
			# string here then we know we've found a bogus stock.

			if ($info{$stock,'last'} eq '') {
				$info{$stock,'success'} = 0;
				$info{$stock,'errormsg'}="Stock does not exist on ASX.";
				next;
			}

			# Drop commas from volume.
			$info{$stock,"volume"} =~ tr/,//d;

			# The ASX returns zeros for a number of things if there
			# has been no trading.  This not only looks silly, but
			# can break things later.  "correct" zero'd data.

			foreach my $label (qw/open high low/) {
				if ($info{$stock,$label} == 0) {
					$info{$stock,$label} = $info{$stock,"last"};
				}
			}

			# Remove trailing percentage sign from p_change
			$info{$stock,"p_change"} =~ tr/%//d;

			# Australian indexes all begin with X, so don't tag them
			# as having currency info.

			$info{$stock, "currency"} = "AUD" unless ($stock =~ /^X/);

			# There are some companies starting with X, so DO tag
			#  them with currency AUD

			if ( grep( /^$stock$/, @ASX_SEC_CODES ) ) {
				$info{$stock, "currency"} = "AUD";
			}

			$info{$stock, "method"} = "asx";
			$info{$stock, "exchange"} = "Australian Stock Exchange";
			$info{$stock, "price"} = $info{$stock,"last"};
			$info{$stock, "success"} = 1;
		}
	}

	# All done.

	return %info if wantarray;
	return \%info;
}

1;

=head1 NAME

Finance::Quote::ASX	- Obtain quotes from the Australian Stock Exchange.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %stockinfo = $q->fetch("asx","BHP");	   # Only query ASX.
    %stockinfo = $q->fetch("australia","BHP"); # Failover to other sources OK.

=head1 DESCRIPTION

This module obtains information from the Australian Stock Exchange
http://www.asx.com.au/.  All Australian stocks and indicies are
available.  Indexes start with the letter 'X'.  For example, the
All Ordinaries is "XAO".

This module is loaded by default on a Finance::Quote object.  It's
also possible to load it explicity by placing "ASX" in the argument
list to Finance::Quote->new().

This module provides both the "asx" and "australia" fetch methods.
Please use the "australia" fetch method if you wish to have failover
with other sources for Australian stocks (such as Yahoo).  Using
the "asx" method will guarantee that your information only comes
from the Australian Stock Exchange.

Information returned by this module is governed by the Australian
Stock Exchange's terms and conditions.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::ASX:
bid, offer, open, high, low, last, net, p_change, volume,
and price.

=head1 SEE ALSO

Australian Stock Exchange, http://www.asx.com.au/

Finance::Quote::Yahoo::Australia.

=cut
