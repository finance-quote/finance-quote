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
require Crypt::SSLeay;

use strict;

use vars qw($VERSION $CREF_URL $TIAA_URL
            %tiaacref_ids %tiaacref_locs %tiaacref_vals);

use LWP::UserAgent;
use HTTP::Request::Common;
use Carp;

$VERSION = '1.02';

# URLs of where to obtain information.
# This used to be different for the CREF and TIAA annuities, but this changed.
$CREF_URL = ("https://www3.tiaa-cref.org/ddata/DownloadData?");

sub methods { return (tiaacref=>\&tiaacref); }

sub labels { return (tiaacref => [qw/method symbol exchange name date isodate nav price/]); }

# =======================================================================
# TIAA-CREF Annuities are not listed on any exchange, unlike their mutual funds
# TIAA-CREF provides unit values via a cgi on their website. The cgi returns
# a csv file in the format 
#		bogus_symbol1,price1,date1
#		bogus_symbol2,price2,date2
#       ..etc.
# where bogus_symbol takes on the following values for the various annuities:
#
# Stock: 				CREFstok
# Money Market:				CREFmony
# Equity Index:				CREFequi
# Inf-Linked Bond:			CREFinfb
# Bond Market:				CREFbond
# Social Choice:			CREFsoci
# Global Equities:			CREFglob
# Growth:				CREFgrow
# TIAA Real Estate:			TIAAreal
# PA Stock Index:			TIAAsndx
# PA Select Stock:			TLSIX
# PA Select Growth Equity:		TLGEX
# PA Select Growth Income:		TLGIX
# PA Select Int'l Equity:		TLIEX
# PA Select Social Choice:		TLSCX
# PA Select Large Cap Value:		TLLCX
# PA Select Small Cap Equity:		TLCEX
# PA Select Real Estate:		TLREX

# TIAA-CREF Money Market:		TIAXX
# TIAA-CREF Bond Plus:			TIPBX
# TIAA-CREF High-Yield Bond:		TCHYX
# TIAA-CREF Inflation-Linked Bond:	TCILX
# TIAA-CREF Short-Term Bond:		TCSTX
# TIAA-CREF Tax-Exempt Bond:		TCTEX
# TIAA-CREF Real Estate Securities:	TCREX
# TIAA-CREF Equity Index:		TCEIX
# TIAA-CREF Growth Equity:		TIGEX
# TIAA-CREF Growth & Income:		TIGIX
# TIAA-CREF International Equity:	TIINX
# TIAA-CREF Large-Cap Value:		TCLCX
# TIAA-CREF Mid-Cap Growth:		TCMGX
# TIAA-CREF Mid-Cap Value:		TCMVX
# TIAA-CREF Small-Cap Equity:		TCSEX
# TIAA-CREF Social Choice Equity:	TCSCX
# TIAA-CREF Managed Allocation:		TIMAX


#
# This subroutine was written by Brent Neal <brentn@users.sourceforge.net>
# Modified to support new TIAA-CREF webpages by Kevin Foss <kfoss@maine.edu> and Brent Neal

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
        $tiaacref_ids{"TLSIX"} = "TIAA Personal Annuity Select Stock Index";
        $tiaacref_ids{"TLGEX"} = "TIAA Personal Annuity Select Growth Equity";
        $tiaacref_ids{"TLGIX"} = "TIAA Personal Annuity Select Growth & Income";
        $tiaacref_ids{"TLIEX"} = "TIAA Personal Annuity Select International Equity";
        $tiaacref_ids{"TLSCX"} = "TIAA Personal Annuity Select Social Choice Equity";
        $tiaacref_ids{"TLLCX"} = "TIAA Personal Annuity Select Large Cap Value";
        $tiaacref_ids{"TLCEX"} = "TIAA Personal Annuity Select Small Cap Equity";
        $tiaacref_ids{"TLREX"} = "TIAA Personal Annuity Select Real Estate Securities";

	# Money Market
	$tiaacref_ids{"TIAXX"} = "TIAA-CREF Money Market";

	# Bonds
	$tiaacref_ids{"TIPBX"} = "TIAA-CREF Bond Plus";
	$tiaacref_ids{"TCHYX"} = "TIAA-CREF High-Yield Bond";
	$tiaacref_ids{"TCILX"} = "TIAA-CREF Inflation-Linked Bond";
	$tiaacref_ids{"TCSTX"} = "TIAA-CREF Short-Term Bond";
	$tiaacref_ids{"TCTEX"} = "TIAA-CREF Tax-Exempt Bond";

	# Real Estate
	$tiaacref_ids{"TCREX"} = "TIAA-CREF Real Estate Securities";

	# Equities
	$tiaacref_ids{"TCEIX"} = "TIAA-CREF Equity Index";
	$tiaacref_ids{"TIGEX"} = "TIAA-CREF Growth Equity";
	$tiaacref_ids{"TIGIX"} = "TIAA-CREF Growth & Income";
	$tiaacref_ids{"TIINX"} = "TIAA-CREF International Equity";
	$tiaacref_ids{"TCLCX"} = "TIAA-CREF Large-Cap Value";
	$tiaacref_ids{"TCMGX"} = "TIAA-CREF Mid-Cap Growth";
	$tiaacref_ids{"TCMVX"} = "TIAA-CREF Mid-Cap Value";
	$tiaacref_ids{"TCSEX"} = "TIAA-CREF Small-Cap Equity";
	$tiaacref_ids{"TCSCX"} = "TIAA-CREF Social Choice Equity";

	$tiaacref_ids{"TIMAX"} = "TIAA-CREF Managed Allocation";
    }
    
    if (! %tiaacref_vals) {
        $tiaacref_vals{"CREFstok"} = "1001";
	$tiaacref_vals{"CREFmony"} = "1008";
	$tiaacref_vals{"CREFequi"} = "1004";
	$tiaacref_vals{"CREFinfb"} = "1007";
	$tiaacref_vals{"CREFbond"} = "1006";
	$tiaacref_vals{"CREFsoci"} = "1005";
	$tiaacref_vals{"CREFglob"} = "1002";
	$tiaacref_vals{"CREFgrow"} = "1003";
	$tiaacref_vals{"TIAAreal"} = "1009";
	$tiaacref_vals{"TIAAsndx"} = "1010";
	$tiaacref_vals{"TLSIX"}    = "1011";
	$tiaacref_vals{"TLGEX"}    = "1012";
	$tiaacref_vals{"TLGIX"}    = "1013";
	$tiaacref_vals{"TLIEX"}    = "1014";
	$tiaacref_vals{"TLSCX"}    = "1015";
	$tiaacref_vals{"TLLCX"}    = "1016";
	$tiaacref_vals{"TLCEX"}    = "1017";
	$tiaacref_vals{"TLREX"}    = "1018";

	$tiaacref_vals{"TIAXX"} = "76";

        $tiaacref_vals{"TIPBX"} = "75";
        $tiaacref_vals{"TCHYX"} = "82";
        $tiaacref_vals{"TCILX"} = "90";
        $tiaacref_vals{"TCSTX"} = "81";
        $tiaacref_vals{"TCTEX"} = "80";

        $tiaacref_vals{"TCREX"} = "89";

        $tiaacref_vals{"TCEIX"} = "84";
        $tiaacref_vals{"TIGEX"} = "72";
        $tiaacref_vals{"TIGIX"} = "73";
        $tiaacref_vals{"TIINX"} = "71";
        $tiaacref_vals{"TCLCX"} = "85";
        $tiaacref_vals{"TCMGX"} = "86";
        $tiaacref_vals{"TCMVX"} = "87";
        $tiaacref_vals{"TCSEX"} = "88";
        $tiaacref_vals{"TCSCX"} = "83";

        $tiaacref_vals{"TIMAX"} = "74";
    }
    
#The location doesn't matter anymore. 
#I'm leaving this data structure in place in case it changes again
#FBN 23/JAN/04
    
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
        $tiaacref_locs{"TIAAsndx"} = 1;
        $tiaacref_locs{"TLSIX"}    = 1;
        $tiaacref_locs{"TLGEX"}    = 1;
        $tiaacref_locs{"TLGIX"}    = 1;
        $tiaacref_locs{"TLIEX"}    = 1;
        $tiaacref_locs{"TLSCX"}    = 1;
        $tiaacref_locs{"TLLCX"}    = 1;
        $tiaacref_locs{"TLCEX"}    = 1;
        $tiaacref_locs{"TLREX"}    = 1;

	$tiaacref_locs{"TIAXX"} = 1;

        $tiaacref_locs{"TIPBX"} = 1;
        $tiaacref_locs{"TCHYX"} = 1;
        $tiaacref_locs{"TCILX"} = 1;
        $tiaacref_locs{"TCSTX"} = 1;
        $tiaacref_locs{"TCTEX"} = 1;

        $tiaacref_locs{"TCREX"} = 1;

        $tiaacref_locs{"TCEIX"} = 1;
        $tiaacref_locs{"TIGEX"} = 1;
        $tiaacref_locs{"TIGIX"} = 1;
        $tiaacref_locs{"TIINX"} = 1;
        $tiaacref_locs{"TCLCX"} = 1;
        $tiaacref_locs{"TCMGX"} = 1;
        $tiaacref_locs{"TCMVX"} = 1;
        $tiaacref_locs{"TCSEX"} = 1;
        $tiaacref_locs{"TCSCX"} = 1;

        $tiaacref_locs{"TIMAX"} = 1;
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
			$cntc++;
			$urlc .=  "f" . $cntc . "=" . $tiaacref_vals{$fund} . "&";
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
    $urlc .=  "days=1";
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
		  $quoter->store_date(\%info, $line[0], {usdate => $line[2]});
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
    PA Select Stock:			TLSIX
    PA Select Growth Equity:		TLGEX
    PA Select Growth Income:		TLGIX
    PA Select Int'l Equity:		TLIEX
    PA Select Social Choice:		TLSCX
    PA Select Large Cap Value:		TLLCX
    PA Select Small Cap Equity:		TLCEX
    PA Select Real Estate:		TLREX

    TIAA-CREF Money Market:             TIAXX
    TIAA-CREF Bond Plus:                TIPBX
    TIAA-CREF High-Yield Bond:          TCHYX
    TIAA-CREF Inflation-Linked Bond:    TCILX
    TIAA-CREF Short-Term Bond:          TCSTX
    TIAA-CREF Tax-Exempt Bond:          TCTEX
    TIAA-CREF Real Estate Securities:   TCREX
    TIAA-CREF Equity Index:             TCEIX
    TIAA-CREF Growth Equity:            TIGEX
    TIAA-CREF Growth & Income:          TIGIX
    TIAA-CREF International Equity:     TIINX
    TIAA-CREF Large-Cap Value:          TCLCX
    TIAA-CREF Mid-Cap Growth:           TCMGX
    TIAA-CREF Mid-Cap Value:            TCMVX
    TIAA-CREF Small-Cap Equity:         TCSEX
    TIAA-CREF Social Choice Equity:     TCSCX
    TIAA-CREF Managed Allocation:       TIMAX


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
