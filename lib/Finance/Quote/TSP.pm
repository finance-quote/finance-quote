#!/usr/bin/perl -w
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@Acpan.org>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#    Copyright (C) 2001, Rob Sessink <rob_ses@users.sourceforge.net>
#    Copyright (C) 2004, Frank Mori Hess <fmhess@users.sourceforge.net>
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

use vars qw($VERSION $TSP_URL); 

use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;

$VERSION = '0.2';

# URLs of where to obtain information

my $TSP_URL = 'http://www.tsp.gov/rates/share-prices.html';

sub methods { return (tsp => \&tsp) }
 
{ 
	my @labels = qw/name nav date currency method/;

	sub labels { return (tsp => \@labels); } 
}

# ==============================================================================
sub tsp {
	my $quoter = shift;
	my @symbols = @_;
	return unless @symbols;
	
	my (%info,$url,$reply,$te);
	my ($row, $datarow, $matches);
	
	my $ua = $quoter->user_agent; 	# user_agent
	$url = $TSP_URL;    		# base url 
 
	$reply = $ua->request(GET $url); 
	
	if ($reply->is_success) { 
	
		#print STDERR $reply->content,"\n";
	
		$te = new HTML::TableExtract(headers => [qw(Date G F C S I)]);
		
		# parse table
		$te->parse($reply->content); 
	}
	foreach my $symbol (@symbols) {
		# check for a page without tables.
		unless ( $te->tables ) 
		{
			$info {$symbol,"success"} = 0;
			$info {$symbol,"errormsg"} = "Fund name $symbol not found, bad symbol name";
			next;
		} 
		# extract table contents
		my @rows; 
		unless (@rows = $te->rows)
		{
			$info {$symbol,"success"} = 0;
			$info {$symbol,"errormsg"} = "Parse error";
			next;
		}
	
		if($reply->is_success == 0)
		{
			$info {$symbol, "success"} = 0;
			$info {$symbol, "errormsg"} = "Error retreiving $symbol ";
			next;
		}
		$info {$symbol, "success"} = 1;
		$info {$symbol, "method"} = "tsp";
		$info {$symbol, "name"} = $symbol;
		if(lc $symbol eq "g" || lc $symbol eq "g fund")
		{
			($info {$symbol, "nav"} = $rows[0][1]) =~ s/\s*//g; # Remove spaces
		}elsif(lc($symbol) eq "f" || lc($symbol) eq "f fund")
		{
			($info {$symbol, "nav"} = $rows[0][2]) =~ s/\s*//g; # Remove spaces
		}elsif(lc($symbol) eq "c" || lc($symbol) eq "c fund")
		{
			($info {$symbol, "nav"} = $rows[0][3]) =~ s/\s*//g; # Remove spaces
		}elsif(lc($symbol) eq "s" || lc($symbol) eq "s fund")
		{
			($info {$symbol, "nav"} = $rows[0][4]) =~ s/\s*//g; # Remove spaces
		}elsif(lc($symbol) eq "i" || lc($symbol) eq "i fund")
		{
			($info {$symbol, "nav"} = $rows[0][5]) =~ s/\s*//g; # Remove spaces
		}else
		{
			$info {$symbol,"success"} = 0;
			$info {$symbol,"errormsg"} = "Unrecognized fund";
		}

		# From a non-working module by Trent Piepho <xyzzy@spekeasy.org>

		# Convert date format.  There is probably a 5000 line perl module that
		# would let me do this same thing in just 3 lines of code instead of 4.
		my %mnames = (Jan => 1, Feb => 2, Mar => 3, Apr => 4, May => 5, Jun => 6,
			      Jul => 7, Aug => 8, Sep => 9, Oct =>10, Nov =>11, Dec =>12);
		$rows[0][0] =~ /(...) (\d\d), (\d\d\d\d)/;
		$info {$symbol, "date"} = "$mnames{$1}/$2/$3";
		
		$info {$symbol, "currency"} = "USD";
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

