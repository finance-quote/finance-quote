#!/usr/bin/perl -w
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@cpan.org>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#
#    Copyright (C) 2001, M.R.Muthu Kumar <m_muthukumar@users.sourceforge.net>
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

package Finance::Quote::Yahoo::Asia;
require 5.005;

use strict;
use HTTP::Request::Common;
use LWP::UserAgent;
use Finance::Quote::Yahoo::Base qw/yahoo_request base_yahoo_labels/;

use vars qw($VERSION $YAHOO_ASIA_URL);

$VERSION = '1.00';

# URLs of where to obtain information.

$YAHOO_ASIA_URL = ("http://sg.finance.yahoo.com/d/quotes.csv");

# Each stock comes back in its own currency, or so it seems.
my %currency_tags = (
	SI => "SGD",
	BO => "INR",
	JK => "IDR",
	HK => "HKD",
	NS => "INR",
	KS => "KRW",
	KL => "MYR",
	NZ => "NZD",
	SS => "CNY",
	SZ => "CNY",
	TW => "TWD",
	TH => "THB"
);

sub methods {return (asia => \&yahoo_asia,yahoo_asia => \&yahoo_asia)};

{
	my @labels = (base_yahoo_labels(),"currency","method");

	sub labels { return (asia => \@labels, yahoo_asia => \@labels); }
}

# =======================================================================
# yahoo_asia gets quotes for Asian (Except Japan) markets from Yahoo.
sub yahoo_asia
{
	my $quoter = shift;
	my @symbols = @_;
	return unless @symbols;	# Nothing if no symbols.

	# This does all the hard work.
	my %info = yahoo_request($quoter,$YAHOO_ASIA_URL,\@symbols);

	foreach my $symbol (@symbols) {
		if ($info{$symbol,"success"}) {
			$info{$symbol,"method"} = "yahoo_asia";

			# Symbols starting with a hat are always
			# indexes, so they don't have a currency.
			if (substr($symbol,0,1) eq "^") {
				$info{$symbol,"currency"} = undef;
			} else {
				my ($exchange) = $symbol =~ /\.([A-Z]{2})$/;
				$info{$symbol,"currency"} = $currency_tags{$exchange};
			}
		}
	}

	return %info if wantarray;
	return \%info;
}

1;

=head1 NAME

Finance::Quote::Yahoo::Asia - Fetch quotes from Yahoo Asia

=head1 SYNOPSIS

    use Finance::Quote;
    $q = Finance::Quote->new;

    %info = $q->fetch("asia","CREA.SI"); # Failover to other methods ok.
    %info = $q->fetch("yahoo_asia","CREA.SI"); # Use this module only.

=head1 DESCRIPTION

This module fetches information from Yahoo Asia.  Symbols should be
provided in the format "SYMBOL.EXCHANGE", where the exchange code is
one of the following:

	SI - Singapore
	BO - Bombay
	JK - Jakarta
	HK - Hong Kong
	NS - India
	KS - Korea
	KL - Kuala Lumpur
	NZ - New Zealand
	SS - Shanghai
	SZ - Shenzhen
	TW - Taiwan
	TH - Thailand

This module provides both the "asia" and "yahoo_asia" methods.
The "asia" method should be used if failover methods are desirable.
The "yahoo_asia" method should be used you desire to only fetch
information from Yahoo Europe.

Stocks are returned in the currency of the local exchange.  You
can use Finance::Quote's set_currency() feature to change the
currency in which information is returned.

This module is loaded by default by Finance::Quote, but can be loaded
explicitly by specifying the parameter "Yahoo::Asia" to
Finance::Quote->new().

Information obtained by this module may be covered by Yahoo's terms
and conditions.  See http://sg.finance.yahoo.com/ for more details.

=head1 LABELS RETURNED

This module returns all the standard labels (where available) provided
by Yahoo.  See Finance::Quote::Yahoo::Base for a list of these.  The
currency label is also returned.

=head1 BUGS

The currency of each exchange has not been thoroughly confirmed.
If you find an exchange is returning in an incorrect exchange,
please use the bug tool at http://sourceforge.net/projects/finance-quote
to report it.

=head1 SEE ALSO

Yahoo Asia, http://sg.finance.yahoo.com/

Finance::Quote::Yahoo::Base

=cut
