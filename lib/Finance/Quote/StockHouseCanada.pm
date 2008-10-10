#!/usr/bin/perl -w

#  StockHouseCanada.pm
#
#  author: Chris Carton (ctcarton@gmail.com)
#  
#  Basic outline of this module was copied 
#  from Cdnfundlibrary.pm
#   
#  Version 0.1 Initial version 
#  Version 0.2, 9April2008, Updated for changed stockhouse.com site. Doug Brown. 
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


package Finance::Quote::StockHouseCanada;
require 5.004;

use strict;

use vars qw($VERSION $STOCKHOUSE_LOOKUP_URL $STOCKHOUSE_URL $STOCKHOUSE_MAIN_URL);

use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;

$VERSION = '1.13_01';

$STOCKHOUSE_LOOKUP_URL="http://www.stockhouse.com/mutualFunds/index.asp?asp=1&lang=&item=searchresult&country=CAN&by=symbol&searchtext=";
$STOCKHOUSE_URL="http://www.stockhouse.com/MutualFunds/index.asp?item=snapshot&page=1&Lang=EN&fundkey=%s&source=Fundata&Symbol=%s&FundName=&CompanyName=&asp=1";
$STOCKHOUSE_MAIN_URL=("http://www.stockhouse.ca");

# FIXME - Add methods to lookup other commodities

sub methods { return (stockhousecanada_fund => \&stockhouse_fund, 
		      canadamutual => \&stockhouse_fund); }

{
    my @labels = qw/name currency last date isodate price source/;
    sub labels { return (stockhousecanada_fund => \@labels,
			 canadamutual => \@labels); }
}

#
# =======================================================================

sub stockhouse_fund  {
    my $quoter = shift;
    my @symbols = @_;

	#print "StockHouseCanada::stockhouse_fund called.\n";

    return unless @symbols;

    my %fundquote;

    my $ua = $quoter->user_agent;
	
    foreach (@symbols) 
    {
		my $mutual = $_;

		# First, we have to get the fund code
		my $url = $STOCKHOUSE_LOOKUP_URL.$mutual;
		my $reply = $ua->request(GET $url);
		# Check the outcome of the response
		if (!$reply->is_success) {
			$fundquote {$mutual,"success"} = 0;
			$fundquote {$mutual,"errormsg"} = "Error retrieving page: $reply->status_line.";
			next;
		}
		unless ($reply->content =~ /fundkey%3D(\d*)/)
		{
			$fundquote {$mutual,"success"} = 0;
			$fundquote {$mutual,"errormsg"} = "Error determining fund code for $mutual.";
			next;
		}
		my $code = $1;
		#print "Code for $mutual is $code.\n";
		
		$url = sprintf($STOCKHOUSE_URL, ($code, $mutual));
		# print "StockHouseCanada using URL $url \n";
		$reply = $ua->request(GET $url);

		$fundquote {$mutual, "symbol"} = $mutual;
		$fundquote {$mutual, "source"} = $STOCKHOUSE_MAIN_URL;
		
		# Check the outcome of the response
		if (!$reply->is_success) {
			$fundquote {$mutual,"success"} = 0;
			$fundquote {$mutual,"errormsg"} = "Error retrieving page: $reply->status_line.";
			next;
		}
  
		# print "Retrieving $url\n";

		$fundquote {$mutual, "success"} = 0;

		next unless ($reply->is_success);

		######################################################
		# debug

		#my $tetest= new HTML::TableExtract( headers => [qw(NAVPS CURRENCY)] );
		#$tetest->parse($reply->content);
		#foreach my $tstest ($tetest->table_states) {
		#    print "\n***\n*** Table (", join(',', $tstest->coords), "):\n***\n";
		#    foreach my $rowtest ($tstest->rows) {
		#	print join(',', @$rowtest), "\n***\n";
		#    }
		#}
		#
		# print $reply->content;
		######################################################

		# We're looking for these 3 things
		my $nav;
		my $currency;
		my $navdate;
                my $name;
		
                # Find name by simple regexp
                if ($reply->content =~ m/<td class=ft_h1>(.*) \($mutual\)<\/td>/ ) {
                  $name = $1 ;
                  #print ">>>$name<<<<\n";
                }
		$fundquote {$mutual, "name"} = $name;

		# Find NAV and Currency via table header
		my $te= new HTML::TableExtract( headers => [qw(NAVPS CURRENCY)] );
		$te->parse($reply->content);
		
		# There should only be one hit
		foreach my $ts ($te->table_states) 
		{
			foreach my $row ($ts->rows)
			{
				$nav = $$row[0];
				$currency = $$row[1];
			}
			last;
		}

		# print "Nav = $nav, currency = $currency\n";
		
		if (!defined($nav))
		{
			$fundquote {$mutual,"success"} = 0;
			$fundquote {$mutual,"errormsg"} = "Error parsing NAV for $mutual.";
			next;
		}
		$fundquote {$mutual, "last"} = $nav;
		$fundquote {$mutual, "price"} = $nav;
		$fundquote {$mutual, "nav"} = $nav;

		if (!defined($currency))
		{
			$fundquote {$mutual,"success"} = 0;
			$fundquote {$mutual,"errormsg"} = "Error parsing currency for $mutual.";
			next;
		}
		$fundquote {$mutual, "currency"} = $currency;

		# I can't find a good anchor for the date, so just look for the label
		if ($reply->content =~ /As of&nbsp;&nbsp;(.*)&nbsp;/)
		{
			$navdate = $1;
		}

                # normalize $navdate to format mm/dd/yyyy by adding zeros where needed
                $navdate =~ s|^(\d)/|0$1/| ; #month
                $navdate =~ s|/(\d)/|/0$1/| ; #day
		#print "Date = $navdate\n";
		
		if (!defined($navdate))
		{
			$fundquote {$mutual,"success"} = 0;
			$fundquote {$mutual,"errormsg"} = "Error parsing date for $mutual.";
			next;
		}
		$fundquote {$mutual, "date"} = $navdate;
                ($fundquote {$mutual, "isodate"} = $navdate) =~ s|(\d+)/(\d+)/(\d+)|$3/$1/$2| ;
                #print "isodate = $fundquote{$mutual,'isodate'}\n";

		$fundquote {$mutual, "success"} = 1;
	}

	return %fundquote if wantarray;
	return \%fundquote;
}

1;

