#!/usr/bin/perl -w
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@cpan.org>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#    Copyright (C) 2000, Volker Stuerzl <volker.stuerzl@gmx.de>
#    Copyright (C) 2006, Klaus Dahlke <klaus.dahlke@gmx.de>
#    Copyright (C) 2008, Stephan Ebelt <stephan.ebelt@gmx.de>
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
# $Id: $

package Finance::Quote::GoldMoney;
require 5.005;
require Crypt::SSLeay;

use HTTP::Request::Common;
use HTML::TableExtract;

use strict;
use warnings;

use vars qw/$VERSION/;

$VERSION = '1.19';

sub methods {
	return(goldmoney => \&goldmoney);
}

sub labels {
	return(goldmoney => [qw/exchange name date isodate price method/]);
}

# goldmoney($quoter, @symbols)
#
# - get 'gold' and 'silver' spot rates from goldmoney.com
# - error out properly (that is: ignore) all other symbols
#
sub goldmoney {
	my $quoter = shift;
	my @symbols = @_;
	return unless @symbols;

	my $ua = $quoter->user_agent;
	my (%symbolhash, @q, %info);
	my (
		$html_string, $te, $table_gold, $table_silver, $table_platinum,
		$gold_gg, $gold_oz, $silver_oz, $platinum_oz, $platinum_pg, $currency
	);

	my $_want_gold = 0;
	my $_want_silver = 0;
	my $_want_platinum = 0;

	# - feed all requested symbols into %info (to be returned later)
	# - set error state to false by default
	# - see if a gold or silver rate is requested
	foreach my $s (@symbols) {
		$info{$s,'success'}  = 0;
		$info{$s,'exchange'} = 'goldmoney.com';
		$info{$s,'method'}   = 'goldmoney';
		$info{$s,'symbol'}   = $s;

		if($s eq 'gold') {
			$_want_gold = 1;
		} elsif($s eq 'silver') {
			$_want_silver = 1;
		} elsif($s eq 'platinum') {
			$_want_platinum = 1;
		} else {
			$info{$s,'errormsg'} = "No data returned (note: this module only works for 'gold' and 'silver')";
		}
	}

	# get the page
	# - but only if we want either gold, silver or platinum (there is nothing else there)
	if( $_want_gold or $_want_silver or $_want_platinum) {
		my $GOLDMONEY_URL = "http://goldmoney.com";
		my $response = $ua->request(GET $GOLDMONEY_URL);

		if ($response->is_success) {
			$html_string =$response->content;

			# we want the 'Current Spot Rates' table
			$te = new HTML::TableExtract->new( attribs=>{class=>'spot'}, subtables=>1);
			$te->parse($html_string);
			$table_gold=$te->table(3,0);
			$table_silver=$te->table(3,1);
			$table_platinum=$te->table(3,2);
		} else {
			# retrieval error - flag an error and return right away
			foreach my $s (@symbols) {
				%info = _goldmoney_error(@symbols, 'HTTP error: ' . $response->status_line);
				return wantarray() ? %info : \%info;
			}
			return wantarray() ? %info : \%info;
		}

		# get list of currencies
		# FIXME:
		# - assume euro since the site change in 01/2009
		# - currency is JavaScript()ed since then and therefore hard to parse, if you
		#   know how please tell me
		# - this assumption causes trouble when the module is used outside the
		#   european region (F::Q considers every number it gets as EUR and converts it...)
		$currency = 'EUR';

		# get gold rate
		#
		if( $_want_gold ) {
			$_ = $table_gold->cell(0,0);
			if( /(\d*\.\d*).*\/gg/ ) {
				$gold_gg = $1;
			}

			$_ = $table_gold->cell(0,0);
			if( /(\d*\.\d*).*\/oz/ ) {
				$gold_oz = $1;

				# assemble final dataset
				# - take "now" as date/time as the site is always current and does
				#   not provide this explicitly - so there is a time-slip
				$quoter->store_date(\%info, 'gold', {isodate => _goldmoney_time('isodate')});
				$info{'gold','time'}     = _goldmoney_time('time');
				$info{'gold','name'}     = 'Gold Spot';
				$info{'gold','last'}     = $gold_oz;
				$info{'gold','price'}    = $gold_oz;
				$info{'gold','price_gg'} = $gold_gg;
				$info{'gold','currency'} = $currency;
				$info{'gold','success'}  = 1;
			}
		}

		# get silver rate
		#
		if( $_want_silver ) {
			$_ = $table_silver->cell(0,0);
			if( /(\d*\.\d*).*\/oz/ ) {
				$silver_oz = $1;

				$quoter->store_date(\%info, 'silver', {isodate => _goldmoney_time('isodate')});
				$info{'silver','time'}     = _goldmoney_time('time');
				$info{'silver','name'}     = 'Silver Spot';
				$info{'silver','last'}     = $silver_oz;
				$info{'silver','price'}    = $silver_oz;
				$info{'silver','currency'} = $currency;
				$info{'silver','success'}  = 1;
			}
		}

		# get platinum rate
		#
		if( $_want_platinum ) {
			$_ = $table_platinum->cell(0,0);
			if( /(\d*\.\d*).*\/pg/ ) {
				$platinum_pg = $1;
			}

			$_ = $table_platinum->cell(0,0);
			if( /(\d*\.\d*).*\/oz/ ) {
				$platinum_oz = $1;

				# assemble final dataset
				# - take "now" as date/time as the site is always current and does
				#   not provide this explicitly - so there is a time-slip
				$quoter->store_date(\%info, 'platinum', {isodate => _goldmoney_time('isodate')});
				$info{'platinum','time'}     = _goldmoney_time('time');
				$info{'platinum','name'}     = 'Platinum Spot';
				$info{'platinum','last'}     = $platinum_oz;
				$info{'platinum','price'}    = $platinum_oz;
				$info{'platinum','price_pg'} = $platinum_pg;
				$info{'platinum','currency'} = $currency;
				$info{'platinum','success'}  = 1;
			}
		}
	}

	return wantarray() ? %info : \%info;
}

# - populate %info with errormsg and status code set for all requested symbols
# - return a hash ready to pass back to fetch()
sub _goldmoney_error {
	my @symbols = shift;
	my $msg     = shift;
	my %info;

	foreach my $s (@symbols) {
		$info{$s, "success"}  = 0;
		$info{$s, "errormsg"} = $msg;
	}

	return(%info);
}

# - return current 'isodate' and 'time' string
sub _goldmoney_time {
	my $want = shift;
	my @now = localtime();
	my $str;

	if($want eq 'isodate') {
		$str = sprintf('%4d-%02d-%02d', $now[5]+1900, $now[4]+1, $now[3]);
	} elsif($want eq 'time') {
		$str = sprintf('%02d:%02d:%02d', $now[2], $now[1], $now[0]);
	}

	return($str);
}

1;

=head1 NAME

Finance::Quote::GoldMoney - obtain spot rates from GoldMoney.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %rates = $q->fetch('goldmoeny','gold', 'silver', 'platinum');

=head1 DESCRIPTION

This module obtains current spot rates for 'gold', 'silver' and
'platinum' from Goldmoney (http://www.goldmoney.com). All other
symbols are ignored.

Information returned by this module is governed by Net Transactions
Ltd.'s terms and conditions. This module is *not* affiliated with the
company in any way. Use at your own risk.

=head1 LABELS RETURNED

The following labels are returned by Finance::Quote::GoldMoney:

	- exchange
	- name
	- date, time
	- price (per ounce), price_gg (per goldgram, gold only),
      price_pg (per platinumgram, platinum only)
    - currency

=head1 SEE ALSO

GoldMoney (Net Transactions Ltd.), http://www.goldmoney.com/

=cut
