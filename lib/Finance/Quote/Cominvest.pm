#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@cpan.org>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#    Copyright (C) 2007, Stephan Ebelt <ste@users.sourceforge.net>
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
# This code initially derived from Padzensky's work on package
# Finance::YahooQuote, but extends its capabilites to encompas a greater
# number of data sources.
#
# This module (cominvest) derived from Finance::Quote::Fidelity because
# it is technically very similar (they provide a list with all funds in
# CSV format...).
#
#

package Finance::Quote::Cominvest;
require 5.005;

use strict;
use vars qw/$COMINVEST_URL $VERSION/;

use LWP::UserAgent;
use HTTP::Request::Common;

$VERSION = '1.13_02';

$COMINVEST_URL = ('http://files.cominvest.de/_fonds_application/FondsInfos/FondsInfos_All_PreiseAktuell_CSVFile.asp?b2b=0&noindex=1&lang=49');

sub methods {
	return (
		cominvest => \&cominvest,
		adig      => \&cominvest
	);
}

sub labels {
	my @labels = qw/exchange name symbol bid ask date isodate yield price method p_change/;
	return (
		cominvest => \@labels,
		adig      => \@labels
	);
}

# ========================================================================
# the cominvest routine gets quotes from "cominvest Asset Management GmbH"
#
sub cominvest {
	my $quoter = shift;
	my @symbols = @_;
	return unless @symbols;
	my(%info, @q, $sym, $k, $ua, $reply);

	# Build a small hash of symbols people want, because it provides a
	# quick and easy way to only return desired symbols.
	my %symbolhash;
	%symbolhash = map{$_, 1} @symbols;

	# Cominvest serves colon separated values (sort of csv's)
	$ua = $quoter->user_agent;
	$reply = $ua->request(GET $COMINVEST_URL);

	if($reply->is_success) {
		foreach (split('\015?\012',$reply->content)) {
			my @q = split(/;/) or next;

			$sym = '';

			# Skip symbols we didn't ask for.
			next unless (
				   (defined($symbolhash{$q[1]}) and $sym=$q[1])  # ISIN
				or (defined($symbolhash{$q[2]}) and $sym=$q[2])  # WKN
			);

			# convert decimal separator to intl. format
			foreach(@q) {
				s/,/\./;
			}

			$info{$sym, 'exchange'}  = 'Cominvest';
			$info{$sym, 'method'}    = 'cominvest';
			$info{$sym, 'name'}      = $q[0];
			$info{$sym, 'symbol'}    = $sym;
			($info{$sym, 'p_change'} = $q[8]) =~ s/\%//;
			$info{$sym, 'yield'}     = $q[9];
			$info{$sym, 'price'}     = $q[7];
			$info{$sym, 'bid'}       = $q[7];
			$info{$sym, 'ask'}       = $q[6];
			$info{$sym, 'currency'}  = $q[3];
			$quoter->store_date(\%info, $sym, {eurodate => $q[5]});

			$info{$sym, 'success'}   = 1;
		}

		# always return a status for all requested symbols
		foreach my $s (@symbols) {
			if( !$info{$s, 'success'} ) {
				$info{$s, 'success'}  = 0;
				$info{$s, 'errormsg'} = 'No data returned';
			}
		}

	} else {
		# set error on all symbols
		foreach my $sym (@symbols) {
			$info{$sym, 'success'}  = 0;
			$info{$sym, 'errormsg'} = 'HTTP error: ' . $reply->status_line;
		}
	}

	return wantarray() ? %info : \%info;
}


1;

=head1 NAME

Finance::Quote::Cominvest - Obtain information from cominvest, formerly known
as Adig Investment.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch('cominvest', '637256');
    %info = Finance::Quote->fetch('adig', 'DE0006372568');

=head1 DESCRIPTION

This module obtains information from cominvest Asset Management
http://www.cominvest-am.de/ - a german mutual fund company. It was formerly
known as Adig Investments and thus an alias 'adig' is also provided.

The name with which this module is called does not change its behavior. It may
be asked for german WKNs or international ISINs.

Information returned by this module is governed by the terms and conditions of
cominvest Asset Management GmbH.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::Cominvest:
exchange, name, bid, ask, date, yield, price, p_change.

=head1 SEE ALSO

cominvest Asset Management, http://www.cominvest-am.de/

=cut
