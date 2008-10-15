#!/usr/bin/perl -w
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@Acpan.org>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#    Copyright (C) 2000, Volker Stuerzl <volker.stuerzl@gmx.de>
#    Copyright (C) 2006, Klaus Dahlke <klaus.dahlke@gmx.de>
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
#
# $Id: DWS.pm,v 1.7 2006/04/08 19:54:55 hampton Exp $

package Finance::Quote::DWS;
require 5.005;
require Crypt::SSLeay;

use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;
use LWP::Simple;
use strict;
use warnings;


use vars qw/$VERSION/;

$VERSION = '1.14';

sub methods {
	return(dwsfunds => \&dwsfunds);
}

sub labels {
	return(dwsfunds => [qw/exchange name date isodate price method/]);
}

# =======================================================================
# The dwsfunds routine gets quotes of DWS funds (Deutsche Bank Gruppe)
# On their website DWS provides a csv file in the format
#    symbol1,price1,date1
#    symbol2,price2,date2
#    ...
#
# This subroutine was written by Volker Stuerzl <volker.stuerzl@gmx.de>
# 
# Version 2.0 as new webpage provides the data
# 2006-03-19: Klaus Dahlke
# Since DWS has changed its format and the data are not available via
# csv-file download, the respective web-page is avaluated. There are
# some limitations currently, especially with the name
#
# 2007-01-19: Stephan Ebelt
# - fixed thousands and decimal separator handling
# - check symbol against ISIN as well
# - populate the exchange field with the DWS subsidiary that actually
#   runs the fund
# - "improved" the name extraction (this fix is questionable, but does what I
#   want for the moment...), falls back to the string length assumption
#   from the last version if there is no match
# - fixed indent
#
# 2007-01-26: Stephan Ebelt
# - fixed 'unitialized value' warnings
#

sub dwsfunds {
	my $quoter = shift;
	my @funds = @_;
	return unless @funds;

	my $ua = $quoter->user_agent;
	my (%fundhash, @q, %info);
	my (
		$html_string, $te, $ts, $row, @cells, $ce, @ce1, @ce2, @ce22, @ce4, $last,
		$wkn, $isin, $exchange, $date, $name, $type
	);

	# define DWS 'Fondsart' (engl: classifications) as used on the page 
	# - these strings are used to break down the real name later
	# - hardcoding at its best... but not much choice in order to get more
	#   correct results
	my @dws_fund_classifications = (
		'Versicherungsfonds',
		'Aktienfonds',
		'Gemischte Fonds',
		'Mitarbeiterfonds',
		'Rentenfonds',
		'Geldmarktnahe Fonds',
		'Dachfonds',
		'Kursgewinn-orientierte Fonds',
		'AS-Fonds',
		'Spezialit.ten',                       # note the dot ;-)
		'Geldmarktfonds',
		'Trading Fonds',
		'DVG Fonds',
		'Wandelanleihen-/ Genussscheinfonds',
		'n/a'
	);

	# create hash of all funds requested
	foreach my $fund (@funds) {
		$fundhash{$fund} = 0;
	}

	# get page containing the tables with prices etc
	my $DWS_URL = "https://www.deami.de/dps/ff/prices.aspx";
	my $response = $ua->request(GET $DWS_URL);

	if ($response->is_success) {
		$html_string =$response->content;

		$te = new HTML::TableExtract->new( depth => 3, count => 1 );
		$te->parse($html_string);
		$ts=$te->table_state(3,1); 
	} else {
		# retrieval error - flag an error and return right away
		foreach my $fund (@funds) {
			%info = _dwsfunds_error(@funds, 'HTTP error: ' . $response->status_line);
			return wantarray() ? %info : \%info;			
		}

		return wantarray() ? %info : \%info;
	}

	#
	#  loop the table rows...
	#
	foreach $row ($ts->rows) {
		@cells =@$row;

		# replace line breaks
		#
		foreach $ce (@cells) {
			next unless $ce;
			$ce =~ s/\n/:/g;
		}

		# verify cell count
		if( $#cells != 4 ) {
			%info = _dwsfunds_error(@funds, "parse error: cells=$#cells, expected cells=4");
			return wantarray() ? %info : \%info;
		}

		# get fond name and exchange
		#
		@ce1=split(/:/, $cells[1]);
		$name     = $ce1[0];
		$exchange = $ce1[1];


		# get date and last price 
		#
		@ce2=split(/:/, $cells[2]);
		$date = $ce2[0];
		$last = $ce2[2];
		
		# 
		# wkn or isin is the source
		#
		@ce4=split(/:/, $cells[4]);
		$wkn=$ce4[1];
		$isin=$ce4[2];

		# match the fund by symbol
		foreach my $fund (@funds) {
			if (  ($wkn eq $fund) or ($isin eq $fund) ) {

				# attempt to separate the name-classification contruct
				my $name_ok = 0;
				foreach my $t (@dws_fund_classifications) {
					if( $name =~ /$t/ ) {
						$type = $t;
				
						my @n = split(/$t/, $name);
						$name = $n[0];
						$name_ok = 1;
				
						last();
					}
				}

				if( ! $name_ok ) {
					# fall back - the last 50 characters are either blanks or fond classification
					$name = substr($name, 0, length($name)-50);
					$info{$fund, "errormsg"} = "name-classification separation failed, guessing...";
				}

				# mangle last price (thousands/decimal separators, ...)
				# - note the decimal separator is hardcoded to ',' (comma)
				# - keep arbitrary precision and any eventually following unit (%, $, ...)
				if( $last =~ /^(.*),(\d*.{1})$/ ) {
					my @tmp = ( $1, $2 );
					$tmp[0] =~ s/\.//g;        
					$last = join('.', @tmp);
				}
				
				# finaly, build up the result
				$info{$fund,"exchange"} = $exchange;
				$info{$fund,"symbol"}   = $fund;
				$quoter->store_date(\%info, $fund, {eurodate => $date});
				$info{$fund,"name"}     = $name;
				$info{$fund,"last"}     = $last;
				$info{$fund,"price"}    = $last;
				$info{$fund,"method"}   = "dwsfunds";
				$info{$fund,"currency"} = "EUR";
				$info{$fund,"success"}  = 1;
				$fundhash{$fund}        = 1;
			}
		}
	}

	# make sure a value is returned for every fund requested
	foreach my $fund (keys %fundhash) {
		if ($fundhash{$fund} == 0) {
			$info{$fund, "success"}  = 0;
			$info{$fund, "errormsg"} = 'No data returned';
		}
	}

	return wantarray() ? %info : \%info;
}

# - populate %info with errormsg and status code set for all requested symbols
# - return a hash ready to pass back to fetch()
sub _dwsfunds_error {
	my @symbols = shift;
	my $msg     = shift;
	my %info;

	foreach my $s (@symbols) {
		$info{$s, "success"}  = 0;
		$info{$s, "errormsg"} = $msg;
	}

	return(%info);
}

1;

=head1 NAME

Finance::Quote::DWS	- Obtain quotes from DWS (Deutsche Bank Gruppe).

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %fundinfo = $q->fetch("dwsfunds","847402", "DE0008474024", ...);

=head1 DESCRIPTION

This module obtains information about DWS managed funds. Query it with
German WKN and/or international ISIN symbols.

Information returned by this module is governed by DWS's terms
and conditions.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::DWS:
exchange, name, date, price, last.

=head1 SEE ALSO

DWS (Deutsche Bank Gruppe), http://www.dws.de/

=cut

 	  	 
