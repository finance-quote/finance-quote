#!/usr/bin/perl -w
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@Acpan.org>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#    Copyright (C) 2001, Tobias Vancura <tvancura@altavista.net>
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

package Finance::Quote::Fool;

use HTTP::Request::Common;
use LWP::UserAgent;
use Exporter;

use vars qw/$FOOL_URL $VERSION @FIELDS $MAX_REQUEST_SIZE @ISA/;

$VERSION = "0.1";

$FOOL_URL = 'http://quote.fool.com/quotes.csv?symbols=';

# This is the maximum number of stocks we'll batch into one operation.
# If this gets too big (>50 or thereabouts) things will break because
# some proxies and/or webservers cannot handle very large URLS.

$MAX_REQUEST_SIZE = 40;

@FIELDS = qw/symbol price change open close high low yhigh ylow div yield vol avg_vol pe/;

sub methods {return (fool   => \&fool)}

# The follow methods are valid, but not enabled for this release until further
# testing has been performed.
#                     usa    => \&fool,
#		     nasdaq => \&fool,
#		     nyse   => \&fool )}
#

{
	my @labels = (base_fool_labels(), "p_change", "currency", "method");

	sub labels { return (fool => \@labels); }
}

sub base_fool_labels {
  return (@FIELDS)
}

# Query the stocks from the Motley Fool website (www.fool.com).  The
# data is returned as comma separated values, similar to Yahoo!Finance

sub fool {
	my $quoter = shift;
	my @stocks = splice(@_, 0, $MAX_REQUEST_SIZE);
	return unless @stocks;
	my %info;

	my $ua = $quoter->user_agent;

	my $response = $ua->request(GET $FOOL_URL.join(",",@stocks));
        return unless $response->is_success;

	# Okay, the data is here
        my $reply = $response->content;
    
        my $i=0;
	foreach (split('\x0D', $reply)) {
	  if ( $i++ ) {    # the first line only contains info about
	                   # the requested data, so we just skip it.
	    my @q = $quoter->parse_csv($_);
	    my $symbol = $q[0];
#	    print "Symbol: $symbol\n";
	    if ($#q != 13) {
	      $info{$symbol, "success"} = 0;
	      $info{$symbol, "errormsg"} = "Stock lookup failed";
#	      print "ERROR\n";
	    } else {
	      for (my $j=1; $j < @FIELDS; $j++) {
#		print "j = $j, $FIELDS[$j], $q[$j]\n";
		$info{$symbol, $FIELDS[$j]} = $q[$j];
	      }
	      $info{$symbol, "currency"} = "USD";
              $info{$symbol, "method"} = "fool";
	         # change_p = change / prev_cl * 100%
	      $info{$symbol, "p_change"} = $q[2]/$q[4]*100;
	    }
	  }
	}
	return %info if wantarray;
	return \%info;
}

1;

=head1 NAME

Finance::Quote::Fool	- Obtain quotes from the Motley Fool web site.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %stockinfo = $q->fetch("fool","GE", "INTC");

=head1 DESCRIPTION

This module obtains information from the Motley Fool website
(www.fool.com). The site provides date from NASDAQ, NYSE and AMEX.

This module is loaded by default on a Finance::Quote object.  It's
also possible to load it explicity by placing "Fool" in the argument
list to Finance::Quote->new().

Information returned by this module is governed by the Motley Fool's
terms and conditions.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::Fool:
symbol, price, change, open, close, high, low, yhigh, ylow,
div, yield, vol, avg_vol, pe, change_p, currency, method.

=head1 SEE ALSO

Motley Fool, http://www.fool.com

Finance::Quote.

=cut
