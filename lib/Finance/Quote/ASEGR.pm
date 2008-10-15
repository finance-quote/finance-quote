#!/usr/bin/perl -w
#    This modules is based on the Finance::Quote::AEX module
#
#    The code has been modified by Morten Cools <morten@cools.no> to be able to
#    retrieve stock information from the Athens Exchange in Greece.
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
require 5.005;

use strict;

package Finance::Quote::ASEGR;

use vars qw($VERSION $ASEGR_URL);

use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;

$VERSION='1.14';

my $ASEGR_URL = 'http://www.ase.gr/content/en/MarketData/Stocks/Prices/Share_SearchResults.asp?';


sub methods { return ( greece => \&asegr,
			asegr => \&asegr,
			europe => \&asegr); }
{ 
	my @labels = qw/name last date isodate p_change open high low close volume currency method exchange/;

	sub labels { return (greece => \@labels,
			     asegr => \@labels,
			     europe => \@labels); } 
}

sub asegr {

	my $quoter = shift;
	my @stocks = @_;
	my (%info,$reply,$url,$te);
	my $ua = $quoter->user_agent();

	$url=$ASEGR_URL;
	
	foreach my $stocks (@stocks)
	{
		$reply = $ua->request(GET $url.join('',"share=",$stocks));

		if ($reply->is_success) 
		{
			
			$te= new HTML::TableExtract( headers =>
			[("Date","Price","\%Change","Volume","Max","Min","Value","Trades","Open")]);

			$te->parse($reply->content);

			unless ( $te->tables)
			{
				$info {$stocks,"success"} = 0;
				$info {$stocks,"errormsg"} = "Stock name $stocks not found";
				next;
			}

			my @rows;
			unless (@rows = $te->rows)
			{
				$info {$stocks,"success"} = 0;
				$info {$stocks,"errormsg"} = "Parse error";
				next;
			}
			
			$info{$stocks, "success"}=1;
			$info{$stocks, "exchange"}="Athens Stock Exchange";
			$info{$stocks, "method"}="asegr";
			$info{$stocks, "name"}=$stocks;
			($info{$stocks, "last"}=$rows[0][1]) =~ s/\s*//g;
			($info{$stocks, "close"}=$rows[1][1]) =~ s/\s*//g;
			($info{$stocks, "p_change"}=$rows[0][2]) =~ s/\s*//g;
			($info{$stocks, "volume"}=$rows[0][3]) =~ s/\s*//g;
			($info{$stocks, "high"}=$rows[0][4]) =~ s/\s*//g; 
			($info{$stocks, "low"}=$rows[0][5]) =~ s/\s*//g;
			($info{$stocks, "nav"}=$rows[0][6]) =~ s/\s*//g;
			($info{$stocks, "open"}=$rows[0][8]) =~ s/\s*//g;

                        $quoter->store_date(\%info, $stocks, {eurodate => $rows[0][0]});

			$info{$stocks,"currency"}="EUR";

			} else {
     			$info{$stocks, "success"}=0;
			$info{$stocks, "errormsg"}="Error retreiving $stocks ";
   }
 } 
 return wantarray() ? %info : \%info;
 return \%info;
}
1;

=head1 NAME

Finance::Quote::ASEGR Obtain quotes from Athens Stock Exchange.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("asegr","minoa");  # Only query ASEGR
    %info = Finance::Quote->fetch("greece","aaak"); # Failover to other sources OK. 

=head1 DESCRIPTION

This module fetches information from the "Athens Stock Exchange",
http://www.ase.gr. All stocks are available. 

This module is loaded by default on a Finance::Quote object. It's 
also possible to load it explicity by placing "ASEGR" in the argument
list to Finance::Quote->new().

This module provides both the "asegr" and "greece" fetch methods.
Please use the "greece" fetch method if you wish to have failover
with future sources for Greek stocks. Using the "asegr" method
will guarantee that your information only comes from the Athens Stock Exchange.
 
Information obtained by this module may be covered by www.ase.gr 
terms and conditions See http://www.ase.gr/ for details.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::ASEGR :
name, last, date, p_change, open, high, low, close, 
volume, currency, method, exchange.

=head1 SEE ALSO

Athens Stock Exchange, http://www.ase.gr

=cut

	
