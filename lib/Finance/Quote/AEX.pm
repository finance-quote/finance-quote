#!/usr/bin/perl -w
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@Acpan.org>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#    Copyright (C) 2001, Rob Sessink <rob_ses@users.sourceforge.net>
#    Copyright (C) 2004, Johan van Oostrum
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

require 5.005;

use strict; 

package Finance::Quote::AEX;

use vars qw($VERSION $AEX_URL); 

use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use HTML::TableExtract;
use CGI;

$VERSION = '1.0';

# URLs of where to obtain information

my $AEX_URL = 'http://www.aex.nl/scripts/marktinfo/koerszoek.asp'; 

sub methods { return (dutch => \&aex,
		      aex   => \&aex) } 
			
{ 
	my @labels = qw/name last date isodate p_change bid offer open high low close volume currency method exchange time/;

	sub labels { return (dutch => \@labels,
			     aex   => \@labels); } 
}

# ==============================================================================
sub aex {
 my $quoter = shift;
 my @symbols = @_;
 return unless @symbols;
   
 my (%info,$url,$reply,$te);
 my ($row, $datarow, $matches);
 my ($time);

 $url = $AEX_URL;    		# base url 

# Create a user agent object and HTTP headers
 my $ua  = new LWP::UserAgent(agent => 'Mozilla/4.0 (compatible; MSIE 5.5; Windows 98)');

 my $headers = new HTTP::Headers(
    Accept => "text/html, text/plain, image/*",
    Content_Type => "application/x-www-form-urlencoded");
 
 foreach my $symbol (@symbols) {

    # Compose form-data
    my $q = new CGI( {zoek => "$symbol"} );
    my $form_data = $q->query_string;

    # Compose POST request
    my $request = new HTTP::Request("POST", $url, $headers);
    #printf $request . "\n";
    $request->content( $form_data );

    # Pass request to the user agent and get a response back
    $reply = $ua->request( $request );

    if ($reply->is_success) { 

     # print STDOUT $reply->content,"\n";

     # Define the headers of the table to be extracted from the received HTML page
     $te = new HTML::TableExtract( headers => [qw(Fonds Current Change Time Bid Offer Volume High Low Open)]);

     # Parse table
     $te->parse($reply->content); 
     
     # Check for a page without tables
     # This gets returned when a bad symbol name is given
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

     # search for the fund within the table-rows (as ther might be other
     # funds having the same fundname in their prefix)
     my $found = 0;
     my $i = 0;
     while ($i < @rows ) {
       my $a = lc($rows[$i][0]);	# convert to lowercase
       my $b = lc($symbol);
       $a =~ s/\s*//g;		# remove spaces
       $b =~ s/\s*//g;
       if ($a eq $b) {
          $found = 1;
          last
       }
       $i++;
     }
 
     unless ( $found ) 
     {
       $info {$symbol,"success"} = 0;
       $info {$symbol,"errormsg"} = "Fund name $symbol not found";
       next;
     }

#    print STDOUT "nr rows: ", $max;
#    print STDOUT "$found,\n rows[", $i, "][0]: $rows[$i][0], symbol: $symbol\n";

#    $info {$symbol, "success"} = 1;
     $info {$symbol, "exchange"} = "Amsterdam Euronext eXchange";
     $info {$symbol, "method"} = "aex";
     $info {$symbol, "symbol"} = $symbol;
     ($info {$symbol, "last"} = $rows[$i][1]) =~ s/\s*//g; # Remove spaces
     ($info {$symbol, "bid"} = $rows[$i][4]) =~ s/\s*//g; 
     ($info {$symbol, "offer"} = $rows[$i][5]) =~ s/\s*//g;
     ($info {$symbol, "high"} = $rows[$i][7]) =~ s/\s*//g; 
     ($info {$symbol, "low"} = $rows[$i][8]) =~ s/\s*//g;
     ($info {$symbol, "open"} = $rows[$i][9]) =~ s/\s*//g;
     ($info {$symbol, "close"} = $rows[$i][1]) =~ s/\s*//g;
     ($info {$symbol, "p_change"} = $rows[$i][2]) =~ s/\s*//g;
     ($info {$symbol, "volume"} = $rows[$i][6]) =~ s/\s*//g;

# Split the date and time from one table entity 
     my $dateTime = $rows[$i][3];

# Check for "dd mmm yyyy hh:mm" date/time format like "01 Aug 2004 16:34" 
     if ($dateTime =~ m/(\d{2}) \s ([a-z]{3}) \s (\d{4}) \s
                        (\d{2}:\d{2})/xi ) { 
       $quoter->store_date(\%info, $symbol, {month => $2, day => $1, year => $3});
       $info {$symbol, "time"} = "$4";
     }

     $info {$symbol, "currency"} = "EUR";
     $info {$symbol, "success"} = 1; 
   } else {
     $info {$symbol, "success"} = 0;
     $info {$symbol, "errormsg"} = "Error retrieving $symbol ";
#    $info {$symbol, "errormsg"} = $reply->message;
   }
 } 

# print STDOUT("Resultaat:  $reply->message \n Fondsnaam: $symbol");

 return %info if wantarray;
 return \%info;
} 
1; 

=head1 NAME

Finance::Quote::AEX Obtain quotes from Amsterdam Euronext eXchange 

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("aex","AAB 93-08 7.5");  # Only query AEX
    %info = Finance::Quote->fetch("dutch","AAB 93-08 7.5"); # Failover to other sources OK 

=head1 DESCRIPTION

This module fetches information from the "Amsterdam Euronext
eXchange AEX" http://www.aex.nl. Only local Dutch investment funds
are available. 

This module is loaded by default on a Finance::Quote object. It's 
also possible to load it explicity by placing "AEX" in the argument
list to Finance::Quote->new().

This module provides both the "aex" and "dutch" fetch methods.
Please use the "dutch" fetch method if you wish to have failover
with future sources for Dutch stocks. Using the "aex" method
will guarantee that your information only comes from the Amsterdam
Euronext eXchange.
 
Information obtained by this module may be covered by www.aex.nl 
terms and conditions See http://www.aex.nl/ for details.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::AEX :
name, last, date, p_change, bid, offer, open, high, low, close, 
volume, currency, method, exchange, time.

=head1 SEE ALSO

Amsterdam Euronext eXchange, http://www.aex.nl

=cut

