#!/usr/bin/perl -w
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@Acpan.org>
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

require 5.005;

use strict;

package Finance::Quote::ASX;

use HTTP::Request::Common;
use LWP::UserAgent;

use vars qw/$ASX_URL $VERSION/;

$VERSION = "1.00";

$ASX_URL = 'http://www3.asx.com.au/nd50/nd_isapi_50.dll/JSP/EquitySearchResults.jsp?method=post&template=F1001&ASXCodes=';

sub methods {return (australia => \&asx,asx => \&asx)}

{
	my @labels = qw/date bid ask open high low last close p_change
	                volume price method exchange/;

	sub labels { return (australia => \@labels,
	                     asx       => \@labels); }
}

# Australian Stock Exchange (ASX)
# The ASX provides free delayed quotes through their webpage.
#
# Maintainer of this section is Paul Fenwick <pjf@schools.net.au>
#
# TODO: It's possible to fetch multiple stocks in one operation.  It would
#       be nice to do this, and should not be hard.
sub asx {
    my $quoter = shift;
    my @stocks = @_;
    return unless @stocks;
    my %info;

    my $ua = $quoter->user_agent;

    foreach my $stock (@stocks) {
        my $response = $ua->request(GET $ASX_URL.$stock);
	unless ($response->is_success) {
	    $info{$stock,"success"} = 0;
	    $info{$stock,"errormsg"} = "HTTP session failed";
	    next;
	}
	my $reply = $response->content;

	# Grab the date.  This is a pretty clunky way of doing it, but
	# my mind's still in brain-saver mode.

	my ($day, $month, $year) = $reply =~ /(\d\d?) (January|February|March|April|May|June|July|August|September|October|November|December) (\d{4})/;

	unless ($month) {
	    $info{$stock,"success"} = 0;
	    $info{$stock,"errormsg"} = "Symbol Lookup failed";
	    next;
	}

	$_ = $month;
	(s/January/1/    or
	 s/February/2/   or
	 s/March/3/      or
	 s/April/4/      or
	 s/May/5/        or
	 s/June/6/       or
	 s/July/7/       or
	 s/August/8/     or
	 s/September/9/  or
	 s/October/10/   or
	 s/November/11/ or
	 s/December/12/  or (warn "Bizarre month $_ from ASX. Skipped $stock\n"
	                          and return));

	$info{$stock,"date"} = "$_/$day/$year"; # Silly 'merkin format.

	# These first two steps aren't really needed, but are done for
	# safety.
	# Remove the bottom part of the page.
	$reply =~ s#</table>\s*\n<table>.*$##s;
	# Remove top of page.
	$reply =~ s#.*<table##s;

        # Now pluck out the headings.
	my @headings;
	while ($reply =~ m#<FONT +SIZE=2><B>([%\w ]*).*?</B>#g) {
	    push @headings, $1;
	}

	# Now grab the values
	my @values;
	while ($reply =~ m#<td align=(left|right)><Font Size=2>(.*?)</Font>#g) {
	    push @values, $2;
	}

	# Put the two together and we get shares information.
	foreach my $heading (@headings) {
	    my $value = shift @values;

	    # Check the code that we got back.
	    if ($heading =~ /ASX CODE/) {
		if ($value ne $stock) {
		    # Oops!  We got back a stock that we didn't want?
		    warn "Bad stocks returned from the ASX.  ".
			 "Wanted $stock but got $value.";
		    return;
		}
		next;
	    }

	    # Convert ASX headings to labels we want to return.
	    $_ = $heading;
	    (s/LAST/last/)  or
	    (s/BID/bid/)    or
	    (s/OFFER/ask/)  or
	    (s/OPEN/open/)  or
	    (s/HIGH/high/)  or
	    (s/LOW/low/)    or
	    (s/LAST/last/)  or
	    (s/PDC/close/)  or
	    (s/%/p_change/) or
	    (s/VOLUME/volume/) or (warn "Unknown heading from ASX: $_.  Skipped"
	                           and next);

	    # Clean the value
	    $value =~ tr/$,%//d;

	    # If the value if nbsp then skip it.  Some things are not
	    # defined outside trading hours.

            next if $value =~ /&nbsp;/;

	    # Put the info into our hash.
	    $info{$stock,$_} = $value;
	}
	$info{$stock,"name"} = $stock;	# ASX doesn't give names.  :(

	# Outside of business hours, the last price is the same as the
	# previous day's close.
	$info{$stock,"last"} ||= $info{$stock,"close"};
	$info{$stock,"price"}  = $info{$stock,"last"};
	$info{$stock,"success"} = 1;

	# Australian indexes all begin with X, so don't tag them
	# as having currency info.
        $info{$stock, "currency"} = "AUD" unless ($stock =~ /^X/);

	$info{$stock, "method"} = "asx";
	$info{$stock, "exchange"} = "Australian Stock Exchange";
    }
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
date, bid, ask, open, high, low, last, close, p_change, volume,
and price.

=head1 SEE ALSO

Australian Stock Exchange, http://www.asx.com.au/

Finance::Quote::Yahoo::Australia.

=cut
