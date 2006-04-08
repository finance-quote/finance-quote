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
use Data::Dumper;
use LWP::Simple;
use strict;
use warnings;


use vars qw/$VERSION/;

$VERSION = '2.00';

sub methods { return (dwsfunds => \&dwsfunds); }
sub labels { return (dwsfunds => [qw/exchange name date isodate price method/]); }

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

sub dwsfunds
{
  my $quoter = shift;
  my @funds = @_;
  return unless @funds;
  my $ua = $quoter->user_agent;
  my (%fundhash, @q, %info);
  my ($html_string, $te, $ts, $row, @cells, $ce, @ce1, @ce2, @ce22, @ce4, $last, $wkn, $date, $name);

  # create hash of all funds requested
  foreach my $fund (@funds)
  {
    $fundhash{$fund} = 0;
  }

  # get page containing the tables with prices etc
  my $DWS_URL = "https://www.deami.de/dps/ff/prices.aspx";
  my $response = $ua->request(GET $DWS_URL);
 if ($response->is_success)
 {
  $html_string =$response->content;
	  #
  $te = new HTML::TableExtract->new( depth => 3, count => 1 );
  $te->parse($html_string);
  $ts=$te->table_state(3,1); 
  foreach $row ($ts->rows) {
     @cells =@$row;
#
# replace line breaks and change from German decimal seperator to intl. decimal seperator
#
     foreach $ce (@cells) {
	next unless $ce;
        $ce =~ s/\n/:/g;
        $ce =~ s/,/\./g;
     }

# get fond name, the last 50 characters are either blanks or fond classification
# 
     @ce1=split(/:/, $cells[1]);
     $name=substr($ce1[0],0,length($ce1[0])-50);
#
# extract the date from the page
#
     @ce2=split(/:/, $cells[2]);
     $date = $ce2[0];
#
# get last price (return value) and remove additional thousand seperator
#
     $last=$ce2[2];
     if ( $last =~ /\d\d.\d\d\d.\d\d/ ) {
        $last =~ s/\.//;
     }
# 
# wkn is the source
#
     @ce4=split(/:/, $cells[4]);
     $wkn=$ce4[1]; 
     foreach my $fund (@funds) {
     if ( $wkn eq $fund ) {
       $info{$fund,"exchange"} = "DWS";
       $info{$fund,"symbol"} = $wkn;
       $quoter->store_date(\%info, $fund, {eurodate => $date});
       $info{$fund,"name"} = $name;
       $info{$fund,"last"} = $last;
       $info{$fund,"price"} = $last;
       $info{$fund,"method"} = "dwsfunds";
       $info{$fund,"currency"} = "EUR";
       $info{$fund,"success"} = 1;
       $fundhash{$fund} = 1;
     }
     }
  }
					   #

    # check to make sure a value was returned for every fund requested
     foreach my $fund (keys %fundhash)
     {
       if ($fundhash{$fund} == 0)
       {
         $info{$fund, "success"}  = 0;
         $info{$fund, "errormsg"} = "No data returned";
       }
     }
}
else
  {
   foreach my $fund (@funds)
   {
    $info{$fund, "success"}  = 0;
    $info{$fund, "errormsg"} = "HTTP error";
    }
    }


  return wantarray() ? %info : \%info;
}


1;

=head1 NAME

Finance::Quote::DWS	- Obtain quotes from DWS (Deutsche Bank Gruppe).

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %fundinfo = $q->fetch("dwsfunds","847402");

=head1 DESCRIPTION

This module obtains information about DWS managed funds.

Information returned by this module is governed by DWS's terms
and conditions.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::DWS:
exchange, name, date, price, last.

=head1 SEE ALSO

DWS (Deutsche Bank Gruppe), http://www.dws.de/

=cut
