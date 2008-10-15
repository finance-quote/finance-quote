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
# This package provides a base class for the various Yahoo services,
# and is based upon code by Xose Manoel Ramos <xmanoel@bigfoot.com>.
# Improvements based upon patches supplied by Peter Thatcher have
# also been integrated.

package Finance::Quote::Yahoo::Base;
require 5.005;

use strict;
use LWP::UserAgent;
use HTTP::Request::Common;
use Exporter;

use vars qw/$VERSION @FIELDS @FIELD_ENCODING $MAX_REQUEST_SIZE @ISA
            @EXPORT @EXPORT_OK/;

@ISA = qw/Exporter/;
@EXPORT = qw//;
@EXPORT_OK = qw/yahoo_request base_yahoo_labels/;

$VERSION = '1.14';

# This is the maximum number of stocks we'll batch into one operation.
# If this gets too big (>50 or thereabouts) things will break because
# some proxies and/or webservers cannot handle very large URLS.

$MAX_REQUEST_SIZE = 40;

# Yahoo uses encodes the desired fields as 1-2 character strings
# in the URL.  These are recorded below, along with their corresponding
# field names.

@FIELDS = qw/symbol name last date time net p_change volume bid ask
             close open day_range year_range eps pe div_date div div_yield
	     cap ex_div avg_vol currency/;

@FIELD_ENCODING = qw/s n l1 d1 t1 c1 p2 v b a p o m w e r r1 d y j1 q a2 c4/;

# This returns a list of labels that are provided, so that code
# that make use of this module can know what it's dealing with.
# It also means that if we extend the code in the future to provide
# more information, we simply need to change this in one spot.

sub base_yahoo_labels {
	return (@FIELDS,"price","high","low");
}

# Yahoo uses a suffix on the stock symbol to denote the exchange on
# which the stock is traded.  Use this suffix to map from the stock
# symbol to the currency in which its prices are reported.

my %currency_tags = (
		      # Country		City/Exchange Name
	US  => "USD", # USA		AMEX, Nasdaq, NYSE
  	A   => "USD", # USA		American Stock Exchange (ASE)
  	B   => "USD", # USA		Boston Stock Exchange (BOS)
  	N   => "USD", # USA		Nasdaq Stock Exchange (NAS)
  	O   => "USD", # USA		NYSE Stock Exchange (NYS)
  	OB  => "USD", # USA		OTC Bulletin Board
  	PK  => "USD", # USA		Pink Sheets
  	X   => "USD", # USA		US Options
	BA  => "ARS", # Argentina	Buenos Aires
	VI  => "EUR", # Austria		Vienna
  	AX  => "AUD", # Australia
	SA  => "BRL", # Brazil		Sao Paolo
  	BR  => "EUR", # Belgium		Brussels
  	TO  => "CAD", # Canada		Toronto
  	V   => "CAD", # 		Toronto Venture
	SN  => "CLP", # Chile		Santiago
	SS  => "CNY", # China		Shanghai
	SZ  => "CNY", # 		Shenzhen
  	CO  => "DKK", # Denmark		Copenhagen
  	PA  => "EUR", # France		Paris
  	BE  => "EUR", # Germany		Berlin
  	BM  => "EUR", # 		Bremen
  	D   => "EUR", # 		Dusseldorf
  	F   => "EUR", # 		Frankfurt
  	H   => "EUR", # 		Hamburg
  	HA  => "EUR", # 		Hanover
  	MU  => "EUR", # 		Munich
  	SG  => "EUR", # 		Stuttgart
  	DE  => "EUR", # 		XETRA
	HK  => "HKD", # Hong Kong
	BO  => "INR", # India		Bombay
	CL  => "INR", # 		Calcutta
	NS  => "INR", # 		National Stock Exchange
	JK  => "IDR", # Indonesia	Jakarta
  	I   => "EUR", # Ireland		Dublin
	TA  => "ILS", # Israel		Tel Aviv
  	MI  => "EUR", # Italy		Milan
	KS  => "KRW", # Korea		Stock Exchange
	KQ  => "KRW", # 		KOSDAQ
	KL  => "MYR", # Malaysia	Kuala Lampur
	MX  => "MXP", # Mexico
	NZ  => "NZD", # New Zealand
  	AS  => "EUR", # Netherlands	Amsterdam
  	OL  => "NOK", # Norway		Oslo
	LM  => "PEN", # Peru		Lima
	IN  => "EUR", # Portugal	Lisbon
	SI  => "SGD", # Singapore
	BC  => "EUR", # Spain		Barcelona
	BI  => "EUR", # 		Bilbao
	MF  => "EUR", # 		Madrid Fixed Income
	MC  => "EUR", # 		Madrid SE CATS
	MA  => "EUR", # 		Madrid
	VA  => "EUR", # 		Valence
  	ST  => "SEK", # Sweden		Stockholm
  	S   => "CHF", # Switzerland	Zurich
	TW  => "TWD", # Taiwan		Taiwan Stock Exchange
	TWO => "TWD", # 		OTC
	BK  => "THB", # Thialand	Thailand Stock Exchange
	TH  => "THB", # 		??? From Asia.pm, (in Thai Baht)
  	L   => "GBP", # United Kingdom	London
);

# yahoo_request (restricted function)
#
# This function expects a Finance::Quote object, a base URL to use,
# a refernece to a list of symbols to lookup.  If a fourth argument is
# used then it will act as a suffix that needs to be appended to the stocks
# in order to obtain the correct information.  This function relies upon 
# the fact that the various Yahoo's all work the same way.

sub yahoo_request {
	my $quoter = shift;
	my $base_url = shift;

	# Extract our original symbols.
	my @orig_symbols = @{shift()};

	# The suffix is used to specify particular markets.
	my $suffix = shift || "";
	
	my $uses_semicolon = shift || 0;

	my %info;
	my $ua = $quoter->user_agent;

	# Generate a suitable URL, now all it needs is the
	# ticker symbols.
	$base_url .= "?f=".join("",@FIELD_ENCODING)."&e=.csv&s=";

	while (my @symbols = splice(@orig_symbols,0,$MAX_REQUEST_SIZE)) {

		# By pushing an extra symbol on to our array, we can
		# be sure that everythng ends up with the correct suffix
		# in the join() below.
		push(@symbols,"");

		my $url = $base_url . join("$suffix+",@symbols);
		chop $url;	# Chop off the final +
		my $response = $ua->request(GET $url);
		return unless $response->is_success;

		# Okay, we have the data.  Just stuff it in
		# the hash now.

		foreach (split('\015?\012',$response->content)) {
			my @q;
			if ($uses_semicolon) {
				@q = $quoter->parse_csv_semicolon($_);
			} else {
				@q = $quoter->parse_csv($_);
			}
			my $symbol = $q[0];
			my ($exchange) = $symbol =~ m/\.([A-Z]+)/;

			# Strip out suffixes.  Mmmm, functions as lvalues.
			substr($symbol,-length($suffix),length($suffix)) = "";

			# If we weren't using a two dimesonal
			# hash, we could do the following with
			# a hash-slice.  Alas, we can't.  This just
			# loads all the returned fields into our hash.

			for (my $i=0; $i < @FIELDS; $i++) {
				# Every now and then on a failed
				# retrieval, Yahoo will drop in an
				# undefined field
				next unless (defined $q[$i] && length $q[$i]);
                                # remove trailing spaces added for
                                # yahoo::europe quotes, since currency
                                # is returned with a trailing white
                                # space
                                $q[$i] =~ s/\s*$// ;
				$info{$symbol,$FIELDS[$i]} = $q[$i];
			}

			# Yahoo returns a line filled with N/A's if we
			# look up a non-existant symbol.  AFAIK, the
			# date flag will /never/ be defined properly
			# unless we've looked up a real stock.  Hence
			# we can use this to check if we've
			# successfully obtained the stock or not.

			if ($info{$symbol,"date"} eq "N/A") {
				$info{$symbol,"success"} = 0;
				$info{$symbol,"errormsg"} = "Stock lookup failed";
				next;
			} else {
				$info{$symbol,"success"} = 1;
			}

			# Whack the dates.  This will add an isodate,
			# and regularize the us date.
			$quoter->store_date(\%info, $symbol, {usdate => $info{$symbol,"date"}});

			$info{$symbol,"price"} = $info{$symbol,"last"};

			# Remove spurious percentage signs in p_change.

			$info{$symbol,"p_change"} =~ s/%//;

			# Extract the high and low values from the
			# day-range, if available

			if ($info{$symbol,"day_range"} =~ m{^"?\s*(\S+)\s*-\s*(\S+)"?$}) {
				$info{$symbol, "low"}  = $1;
				$info{$symbol, "high"} = $2;
			}

                        if (defined($info{$symbol,"time"})) {
                          # uniform time output
                          $info{$symbol,"time"} = $quoter->isoTime($info{$symbol,"time"});
                        }

			if (defined($info{$symbol,"currency"})) {
			  # Convert the currency to be all uppercase for
			  # backward compatability.  Needed because Yahoo
			  # returns GBP as GBp.  There may be others.
			  $info{$symbol,"currency"} =~ tr/a-z/A-Z/;
                          # yahoo started to return GBX instead of GBP
                          # somewhere arround 9 oct 2008.
                          $info{$symbol,"currency"} =~ s/GBX/GBP/;
#			  printf "Currency %s specified by Yahoo\n", $info{$symbol,"currency"};
			} else {
			  # Determine the currency from the exchange name.
			  # Symbols without an exchange are in USD. Symbols
			  # starting with a hat are always indexes, so they
			  # don't have a currency.
			  if (defined($exchange)) {
			    $info{$symbol,"currency"} = $currency_tags{$exchange};
#			    print "Set currency based on exchange $exchange\n";
			  } elsif (substr($symbol,0,1) ne "^") {
#			    print "No exchange, not an index, set currency to USD\n";
			    $info{$symbol,"currency"} = "USD";
			  }
			  $info{$symbol,"currency_set_by_fq"} = 1;
			}

			# Convert prices (when needed). E.G. London sources
			# return in pence. We'd like them to return in pounds
			# (divide by 100).
			if (defined($exchange)) {
			  if (($exchange eq "L"  && $info{$symbol,"currency"} eq "GBP") ||
			      ($exchange eq "TA")) {
			    foreach my $field ($quoter->default_currency_fields) {
			      next unless ($info{$symbol,$field});
			      $info{$symbol,$field} =
				$quoter->scale_field($info{$symbol,$field},0.01);
			    }
			  }
			  # Other exchanges here as needed.
			}

		} # End of processing each stock line.
	} # End of lookup loop.

	# Return undef's rather than N/As.  This makes things more suitable
	# for insertion into databases, etc.  Also remove silly HTML that
	# Yahoo inserts to put in little Euro symbols and stuff.  It's
	# pretty stupid to have HTML tags in a CSV file in the first
	# place, don't you think?

	foreach my $key (keys %info) {
	  #if (!defined $info{$key}) {
	  #  printf STDERR "\n";
	  #  printf STDERR "$key points to undefined value\n";
	  #  printf STDERR "\n";
	  #}
	  if (defined $info{$key}) {
	    $info{$key} =~ s/<[^>]*>//g;
	    $info{$key} =~ s/&nbsp;.*$//;
	    undef $info{$key} if ($info{$key} eq "N/A");
	  }
	}
	return %info if wantarray;
	return \%info;
}

1;

=head1 NAME

Finance::Quote::Yahoo::Base - Common functions for fetching Yahoo info.

=head1 SYNOPSIS

Base functions for use by the Finance::Quote::Yahoo::* modules.

=head1 DESCRIPTION

This module is not called directly, rather it provides a set of
base functions which other Yahoo-related modules can use.  If you're
thinking of writing a module to fetch specific information from
Yahoo, then you might wish to look through the source code for
this module.

=head1 LABELS RETURNED

Most Yahoo functions will return a standard set of labels.  These
include (where available): symbol, name, last, date, time, net,
p_change, volume, bid, ask close, open, day_range, year_range, eps,
pe, div_date, div, div_yield, cap, ex_div, avg_vol.

=head1 SEE ALSO

Finance::Quote::Yahoo::Australia, Finance::Quote::Yahoo::USA,
Finance::Quote::Yahoo::Europe.

=cut
