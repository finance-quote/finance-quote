#!/usr/bin/perl -w
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@cpan.org>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#    Copyright (C) 2001, Rob Sessink <rob_ses@users.sourceforge.net>
#    Copyright (C) 2004, Frank Mori Hess <fmhess@users.sourceforge.net>
#                        Trent Piepho <xyzzy@spekeasy.org>
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
# This code is derived from version 0.9 of the AEX.pm module.

require 5.005;

use strict;

package Finance::Quote::TSP;

use vars qw($VERSION $TSP_URL $TSP_MAIN_URL %TSP_FUND_COLUMNS %TSP_FUND_NAMES);

use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;

$VERSION = '1.17';

# URLs of where to obtain information

$TSP_URL = 'http://www.tsp.gov/rates/share-prices.html';
$TSP_MAIN_URL=("http://www.tsp.gov");

%TSP_FUND_COLUMNS = (
    TSPL2040FUND => "L 2040",
    TSPL2030FUND => "L 2030",
    TSPL2020FUND => "L 2020",
    TSPL2010FUND => "L 2010",
    TSPLINCOMEFUND => "L INCOME",
    TSPGFUND => "G FUND",
    TSPFFUND => "F FUND",
    TSPCFUND => "C FUND",
    TSPSFUND => "S FUND",
    TSPIFUND => "I FUND" );

%TSP_FUND_NAMES = (
    TSPL2040 => 'Lifecycle 2040 Fund',
    TSPL2030 => 'Lifecycle 2030 Fund',
    TSPL2020 => 'Lifecycle 2020 Fund',
    TSPL2010 => 'Lifecycle 2010 Fund',
    TSPLINCOME => 'Lifecycle Income Fund',
    TSPGFUND => 'Government Securities Investment Fund',
    TSPFFUND => 'Fixed Income Index Investment Fund',
    TSPCFUND => 'Common Stock Index Investment Fund',
    TSPSFUND => 'Small Capitalization Stock Index Investment Fund',
    TSPIFUND => 'International Stock Index Investment Fund' );

sub methods { return (tsp => \&tsp) }
 
{ 
	my @labels = qw/name nav date isodate currency method/;

	sub labels { return (tsp => \@labels); } 
}

# ==============================================================================
sub tsp {
	my $quoter = shift;
	my @symbols = @_;

	# Make sure symbols are requested  
	##CAN exit more gracefully - add later##

	return unless @symbols;

	# Local Variables
	my(%info, %fundrows);
	my($ua, $reply, $row, $te);

	$ua = $quoter->user_agent;
	$reply = $ua->request(GET $TSP_URL);
	return unless ($reply->is_success);
	$te = new HTML::TableExtract( headers => 
		["Date", values %TSP_FUND_COLUMNS] );

	$te->parse($reply->content);

	# First row is newest data, older data follows, maybe there
	# should be some way to get it?
	$row = ($te->rows())[0];

	# Make a hash that maps the order the columns are in
	for(my $i=1; my $key = each %TSP_FUND_COLUMNS ; $i++) {
	    $fundrows{$key} = $i;
	}

	foreach (@symbols) {
	    # Ignore case when looking up the data.  Preserve case
	    # when storing the symbol name in the info array.
	    my $tmp = uc $_;
	    $tmp = uc sprintf("TSP%sfund", substr($tmp,0,1))
	      if (index("GFCSI", substr($tmp,0,1)) >= 0);
		if (index("LINCOME", substr($tmp,0,7)) >= 0)
		{
			$tmp = uc sprintf("TSP%sfund", substr($tmp,0,7));
		} elsif (index("L", substr($tmp,0,1)) >= 0) {
			$tmp = uc sprintf("TSP%sfund", substr($tmp,0,5));
		}

	    if(exists $fundrows{$tmp}) {
		$info{$_, 'success'} = 1;

		$info{$_, 'method'} = 'tsp';
		$info{$_, 'currency'} = 'USD';
		$info{$_, 'source'} = $TSP_MAIN_URL;
		$info{$_, 'symbol'} = $_;
		$info{$_, 'name'} = $TSP_FUND_NAMES{$tmp};
		($info{$_, 'nav'} = $$row[$fundrows{$tmp}]) =~ s/[^0-9]*([0-9.,]+).*/$1/s;
		$info{$_, 'last'} = $info{$_, 'nav'};
		$quoter->store_date(\%info, $_, {usdate => $$row[0]});
	    } else {
		$info{$_, 'success'} = 0;
		$info{$_, 'errormsg'} = "Fund name unknown";
	    }
	}
	return %info if wantarray;
	return \%info;
} 
1; 

=head1 NAME

Finance::Quote::TSP Obtain fund prices for US Federal Government Thrift Savings Plan

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("tsp","c"); #get value of C "Common Stock Index Investment" Fund

=head1 DESCRIPTION

This module fetches fund information from the "Thrift Savings Plan" 
homepage http://www.tsp.gov.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::TSP :
name nav date currency method

=head1 SEE ALSO

Thrift Savings Plan, http://www.tsp.gov

=cut

