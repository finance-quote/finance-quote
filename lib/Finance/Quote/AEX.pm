#!/usr/bin/perl -w
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@Acpan.org>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#    Copyright (C) 2001, Rob Sessink <rob_ses@users.sourceforge.net>
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
use HTTP::Request::Common;
use HTML::TableExtract;

$VERSION = '0.9';

# URLs of where to obtain information

my $AEX_URL = 'http://www.aex.nl/scripts/pop/kb.asp?';

sub methods { return (dutch => \&aex,
		      aex   => \&aex) } 
			
{ 
	my @labels = qw/name last date p_change bid offer open high low close volume currency method exchange time/;

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

 my $ua = $quoter->user_agent; 	# user_agent
 $url = $AEX_URL;    		# base url 
 
 foreach my $symbols (@symbols) {
    $reply = $ua->request(GET $url.join('',"taal=en&alf=",$symbols)); 
   
   if ($reply->is_success) { 
   
    #print STDERR $reply->content,"\n";
   
     $te = new HTML::TableExtract( headers => [("Stock","Time","Volume")]);
 
     # parse table
     $te->parse($reply->content); 
     
     # check for a page without tables.
     # This gets returned when a bad symbol name is given.
     unless ( $te->tables ) 
     {
       $info {$symbols,"succes"} = 0;
       $info {$symbols,"errormsg"} = "Fund name $symbols not found, bad symbol name";
     next;
     } 
     
     # extract table contents
     my @rows; 
     unless (@rows = $te->rows)
     {
       $info {$symbols,"success"} = 0;
       $info {$symbols,"errormsg"} = "Parse error";
       next;
     }
    
     $info {$symbols, "success"} = 1;
     $info {$symbols, "exchange"} = "Amsterdam Euronext eXchange";
     $info {$symbols, "method"} = "aex";
     $info {$symbols, "name"} = $symbols;
     ($info {$symbols, "last"} = $rows[0][0]) =~ s/\s*//g; # Remove spaces
     ($info {$symbols, "bid"} = $rows[1][0]) =~ s/\s*//g; 
     ($info {$symbols, "offer"} = $rows[2][0]) =~ s/\s*//g;
     ($info {$symbols, "high"} = $rows[3][0]) =~ s/\s*//g; 
     ($info {$symbols, "low"} = $rows[4][0]) =~ s/\s*//g;
     ($info {$symbols, "open"} = $rows[5][0]) =~ s/\s*//g;
     ($info {$symbols, "close"} = $rows[6][0]) =~ s/\s*//g;
     ($info {$symbols, "p_change"} = $rows[7][1]) =~ s/\s*//g;
     ($info {$symbols, "volume"} = $rows[0][2]) =~ s/\s*//g;
     
     # Split the date and time from one table entity 
     ($info {$symbols, "date"} = $rows[0][1]) =~ s/\d{2}:\d{2}//;  
     ($info {$symbols, "time"} = $rows[0][1]) =~ s/\d{2}\s\w{3}\s\d{4}\s//;
     
    # Remove spaces at the front and back of the date 
     $info {$symbols, "date"} =~ s/^\s*|\s*$//g;
     $info {$symbols, "time"} =~ s/\s*//g;
    
    # convert date from dutch (dd mm yyyy) to US format (mm/dd/yyyy)
     my @date = split /\s/, $info {$symbols, "date"};
     $info {$symbols, "date"} = $date[1]."/".$date[0]."/".$date[2]; 
     
     $info {$symbols, "currency"} = "EUR";
     $info {$symbols, "success"} = 1; 
   } else {
     $info {$symbols, "success"} = 0;
     $info {$symbols, "errormsg"} = "Error retreiving $symbols ";
   }
 } 
 return %info if wantarray;
 return \%info;
} 
1; 

=head1 NAME

Finance::Quote::AEX Obtain quotes from Amsterdam Euronext eXchange 

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("aex","asml");  # Only query AEX
    %info = Finance::Quote->fetch("dutch","phi"); # Failover to other sources OK. 

=head1 DESCRIPTION

This module fetches information from the "Amsterdam Euronext
eXchange AEX" http://www.aex.nl. All dutch stocks and indices are
available. 

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

