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
#
# This code derived from Padzensky's work on package Finance::YahooQuote,
# but extends its capabilites to encompas a greater number of data sources.
#
# This code was developed as part of GnuCash <http://www.gnucash.org/>

package Finance::Quote::Tiaacref;
require 5.005;

use strict;

use vars qw($VERSION $CREF_URL $TIAA_URL %tiaacref_ids %tiaacref_locs);

use LWP::UserAgent;
use HTTP::Request::Common;
use Carp;

$VERSION = '1.01';

# URLs of where to obtain information.

$CREF_URL = ("http://www.tiaa-cref.org/financials/selection/ann-select.cgi?");
$TIAA_URL = ("http://www.tiaa-cref.org/financials/selection/pa-select.cgi?");

sub methods { return (tiaacref=>\&tiaacref); }

sub labels { return (tiaacref => [qw/method symbol exchange name date nav price/]); }

# =======================================================================
# TIAA-CREF Annuities are not listed on any exchange, unlike their mutual funds
# TIAA-CREF provides unit values via a cgi on their website. The cgi returns
# a csv file in the format 
#		bogus_symbol1,price1,date1
#		bogus_symbol2,price2,date2
#       ..etc.
# where bogus_symbol takes on the following values for the various annuities:
#
#Stock: 			CREFstok
#Money Market:			CREFmony
#Equity Index:			CREFequi
#Inf-Linked Bond:		CREFinfb
#Bond Market:			CREFbond
#Social Choice:			CREFsoci
#Global Equities:		CREFglob
#Growth:			CREFgrow
#TIAA Real Estate:		TIAAreal
#PA Stock Index:		TIAAsndx
#PA Select Stock:		TIAAsele
#PA Select Growth Equity:	TIAAgreq
#PA Select Growth Income:	TIAAgrin
#PA Select Int'l Equity:	TIAAintl
#PA Select Social Choice:	TIAAsocl

#
# This subroutine was written by Brent Neal <brentn@users.sourceforge.net>
#
# TODO:
#
# The TIAA-CREF cgi allows you to specify the exact dates for which to retrieve
# price data. That functionality could be worked into this subroutine.
# Currently, we only grab the most recent price data.
# 

sub tiaacref
{
    my $quoter = shift;
    if (! %tiaacref_ids ) {  #build a name hash for the annuities (once only)
    	$tiaacref_ids{"CREFstok"} = "CREF Stock";
    	$tiaacref_ids{"CREFmony"} = "CREF Money Market";
    	$tiaacref_ids{"CREFequi"} = "CREF Equity Index";
    	$tiaacref_ids{"CREFinfb"} = "CREF Inflation-Linked Bond";
    	$tiaacref_ids{"CREFbond"} = "CREF Bond Market";
    	$tiaacref_ids{"CREFsoci"} = "CREF Social Choice";
    	$tiaacref_ids{"CREFglob"} = "CREF Global Equities";
    	$tiaacref_ids{"CREFgrow"} = "CREF Growth";
    	$tiaacref_ids{"TIAAreal"} = "TIAA Real Estate";
    	$tiaacref_ids{"TIAAsndx"} = "TIAA Teachers Personal Annuity Stock Index";
    	$tiaacref_ids{"TIAAsele"} = "TIAA Teachers Personal Annuity Select Stock"; 
	$tiaacref_ids{"TIAAgreq"} = "TIAA Teachers Personal Annuity Select Growth Equity";
        $tiaacref_ids{"TIAAgrin"} = "TIAA Teachers Personal Annuity Select Growth Income";
        $tiaacref_ids{"TIAAintl"} = "TIAA Teachers Personal Annuity Select International Equity";
        $tiaacref_ids{"TIAAsocl"} = "TIAA Teachers Personal Annuity Select Social Choice Equity";
    }
    if (! %tiaacref_locs) {
        $tiaacref_locs{"CREFstok"} = 1;
        $tiaacref_locs{"CREFmony"} = 1;
        $tiaacref_locs{"CREFequi"} = 1;
        $tiaacref_locs{"CREFinfb"} = 1;
        $tiaacref_locs{"CREFbond"} = 1;
        $tiaacref_locs{"CREFsoci"} = 1;
        $tiaacref_locs{"CREFglob"} = 1;
        $tiaacref_locs{"CREFgrow"} = 1;
        $tiaacref_locs{"TIAAreal"} = 1;
        $tiaacref_locs{"TIAAsndx"} = 2;
        $tiaacref_locs{"TIAAsele"} = 2;
        $tiaacref_locs{"TIAAgreq"} = 2;
        $tiaacref_locs{"TIAAgrin"} = 2;
        $tiaacref_locs{"TIAAintl"} = 2;
        $tiaacref_locs{"TIAAsocl"} = 2;
    }
    my(@funds) = @_;
    return unless @funds;
    my(@line);		#holds the return from parse_csv
    my(%info);
    my(%check);		#holds success value if data returned	
    my($ua,$urlc,$urlt);   #useragent and target urls
    my($cntc,$cntt); #counters for each of the two url containers
    my($reply,$qdata);		#the reply from TIAA-CREF's cgi and a buffer for the data

#    $url = $TIAACREF_URL;
    $urlc = $CREF_URL;
    $urlt = $TIAA_URL;
#Initialize counters for the two types of URL. If either counter is zero, then
# that URL will not be retrieved. This is less technically clever than testing
#the URL string itself with m/yes/, but its faster.
    $cntc = 0;
    $cntt = 0;
    foreach my $fund (@funds) {
	if ($tiaacref_ids{$fund}) {
        	if ($tiaacref_locs{$fund} == 1) {
			$urlc .=  $fund . "=yes&";
			$cntc++;
		} else {
			$urlt .= $fund . "=yes&";
			$cntt++;
		}
		$check{$fund} = 0;
	} else {
		$info{$fund,"success"} = 0;
		$info{$fund,"errormsg"} = "Bad symbol";
	}
    }
    $urlc .=  "selected=1";
    $urlt .=  "selected=1";
    $qdata ="";
    $ua = $quoter->user_agent;
    if ($cntc) {
    	$reply = $ua->request(GET $urlc);
        if ($reply ->is_success) {
            $qdata .= $reply->content;
	}
    }
    if ($cntt) {
        $reply = $ua->request(GET $urlt);
        if ($reply ->is_success) {
            $qdata .= $reply->content;
	}
    }
    if (length($qdata)) {
       foreach (split('\012',$qdata) ){
           @line = $quoter->parse_csv($_);
           if (exists $check{$line[0]}) {   #did we ask for this data?
		  $info{$line[0],"symbol"} = $line[0]; #in case the caller needs this in the hash
         	  $info{$line[0],"exchange"} = "TIAA-CREF";
         	  $info{$line[0],"name"} = $tiaacref_ids{$line[0]};
         	  $info{$line[0],"date"} = $line[2];
         	  $info{$line[0],"nav"} =  $line[1];	
		  $info{$line[0],"price"} = $info{$line[0],"nav"};
	 	  $info{$line[0],"success"} = 1; #this contains good data, 
                                                 #beyond a reasonable doubt
                  $info{$line[0],"currency"} = "USD";
		  $info{$line[0],"method"} = "tiaacref";
		  $info{$line[0],"exchange"} = "TIAA-CREF";
	 	  $check{$line[0]} = 1;
	  } else {
	  	$info{$line[0],"success"} = 0;
	  	$info{$line[0],"errormsg"} = "Bad data returned";
	  }
       }
    } else {
	foreach $_ (@funds) {
		$info{$_,"success"} = 0;
		$info{$_,"errormsg"} = "HTTP error";
	} # foreach
	
    } #if $length(qdata) else
    
    
    #now check to make sure a value was returned for every symbol asked for
    foreach my $k (keys %check) {
    	if ($check{$k} == 0) {
    		$info{$k,"success"} = 0;
    		$info{$k,"errormsg"} = "No data returned";
    	}
    }

    return %info if wantarray;
    return \%info;
}

1;

=head1 NAME

Finance::Quote::Tiaacref	- Obtain quote from TIAA-CREF.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %stockinfo = $q->fetch("tiaacref","TIAAreal");

=head1 DESCRIPTION

This module obtains information about TIAA-CREF managed funds.

The following symbols can be used:

    Stock: 				CREFstok
    Money Market:			CREFmony
    Equity Index:			CREFequi
    Inf-Linked Bond:			CREFinfb
    Bond Market:			CREFbond
    Social Choice:			CREFsoci
    Global Equities:			CREFglob
    Growth:				CREFgrow
    TIAA Real Estate:			TIAAreal
    PA Stock Index:			TIAAsndx
    PA Select Stock:			TIAAsele
    PA Select Growth Equity:      	TIAAgreq
    PA Select Growth Income:       	TIAAgrin
    PA Select Int'l Equity:        	TIAAintl
    PA Select Social Choice:       	TIAAsocl

This module is loaded by default on a Finance::Quote object.  It's
also possible to load it explicitly by passing "Tiaacref" in to the
argument argument list of Finance::Quote->new().

Information returned by this module is governed by TIAA-CREF's terms
and conditions.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::Tiaacref:
symbol, exchange, name, date, nav, price.

=head1 SEE ALSO

TIAA-CREF, http://www.tiaa-cref.org/

=cut
