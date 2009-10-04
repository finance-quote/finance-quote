#!/usr/bin/perl -w
#
#    Copyright (C) 2003, Rob Clark <finiteautomaton@users.sourceforge.net>
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
# 

require 5.005;

use strict;

package Finance::Quote::BMONesbittBurns;

use vars qw($VERSION $BMO_URL); 

use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;

$VERSION = '1.17';

# URLs of where to obtain information
my $BMO_URL = 'http://bmonesbittburns.com/QuickQuote/QuickQuote.asp?Symbol=';

sub methods { return (bmonesbittburns => \&bmonesbittburns) } 
sub labels  { return (bmonesbittburns => [qw/name last p_change bid offer open high low volume currency method exchange date isodate time/]) };
			
# ==============================================================================
sub bmonesbittburns {
    my $quoter = shift;
    my @symbols = @_;
    return unless @symbols;

    my($url, $reply, $te);
    my(%info);
    
    my $ua = $quoter->user_agent; 	# user_agent
    $url = $BMO_URL;    		    # base url 
    
    foreach my $symbol (@symbols) {
        $reply = $ua->request(GET $url.join('',$symbol)); 
        
        if ($reply->is_success) { 
        
            #print STDERR $reply->content,"\n";
            
            $te = new HTML::TableExtract( depth => 2);

            # parse table
            $te->parse($reply->content); 
            
            # check for a page without tables.
            # This gets returned when a bad symbol name is given.
            unless ( $te->tables )  {
                $info {$symbol,"succes"} = 0;
                $info {$symbol,"errormsg"} = "Fund name $symbol not found, bad symbol name";
                next;
            } 
            
	    if (0) {
	      my ($table, $row);

	      # Old style, using top level methods rather than table state objects.
	      foreach $table ($te->tables) {
		print "Table (", join(',', $te->table_coords($table)), "):\n";
		foreach $row ($te->rows($table)) {
		  print join(',', @$row), "\n";
		}
	      }
	    }

            # extract table contents
            my($ignored, $stock_info, $data) = $te->table_states;
            my(@rows) = $data->rows;

            unless ($stock_info && $rows[0][1] !~ /Error/) {
                $info {$symbol,"success"} = 0;
                $info {$symbol,"errormsg"} = "Parse error";
                next;
            }

            my(@info_row) = $stock_info->rows;
            if ( $info_row[0][2] !~ /\w/ ) {
                # No text name associated with the stock, use the symbol name
                $info {$symbol, "name"} = $symbol;
            }
            else {
                $info {$symbol, "name"} = $info_row[0][2];
            }
            # Strip leading and trailing spaces
            $info {$symbol, "name"} =~ s/^\s*//;
            $info {$symbol, "name"} =~ s/\s*$//;

            $info {$symbol, "success"} = 1;
            $info {$symbol, "exchange"} = "BMO Nesbitt Burns";
            $info {$symbol, "method"} = "bmonesbittburns";
            
            ($info {$symbol, "last"}      = $rows[ 1][2]) =~ s/\s*//g; # Remove spaces
            ($info {$symbol, "p_change"}  = $rows[ 2][5]) =~ s/\s*//g;
            ($info {$symbol, "close"}     = $rows[ 3][5]) =~ s/\s*//g;
            ($info {$symbol, "bid"}       = $rows[ 4][2]) =~ s/\s*//g; 
            ($info {$symbol, "offer"}     = $rows[ 4][5]) =~ s/\s*//g;
            ($info {$symbol, "open"}      = $rows[ 6][2]) =~ s/\s*//g;
            ($info {$symbol, "volume"}    = $rows[ 6][5]) =~ s/\s*//g;
            ($info {$symbol, "high"}      = $rows[ 7][2]) =~ s/\s*//g; 
            ($info {$symbol, "low"}       = $rows[ 7][5]) =~ s/\s*//g;
            if ($#rows >= 9) {
                ($info {$symbol, "eps"}       = $rows[10][2]) =~ s/\s*//g; 
                ($info {$symbol, "pe"}        = $rows[10][5]) =~ s/\s*//g;
                ($info {$symbol, "div_yield"} = $rows[12][5]) =~ s/\s*//g;

                $rows[9][2] =~ s/[^\d\.]*//g; # Strip spaces and funky 8-bit characters
                $rows[9][5] =~ s/[^\d\.]*//g;
                $info {$symbol, "year_range"} = $rows[9][5] . " - " . $rows[9][2];
            }

	    # This site appears to provide either a date or a time but not both
            my($dt) = $rows[3][2];
            if ($dt =~ /:/) {
                ($info {$symbol, "time"} = "$dt:00") =~ s/\s*//g; 
		$quoter->store_date(\%info, $symbol, {today => 1});
            }
            else {
                my ($month, $day) = ($dt =~ /([0-9]+)\/([0-9]+)/);
		$quoter->store_date(\%info, $symbol, {day => $day, month => $month});
                $info {$symbol, "time"} = "00:00:00";
            }

            # If this was a US exchange, currency in US$
            if ($symbol =~ /,X$/) {
                $info {$symbol, "currency"} = "USD";
            }
            else {
                $info {$symbol, "currency"} = "CAD";
            }
            $info {$symbol, "success"} = 1; 

            # Walk through our fields and remove high-ascii
	    # characters which may have snuck in.
	    
	    foreach (@{labels()}) {
                $info{$symbol,$_} =~ tr/\200-\377//d;
	    }

        } else {
            $info {$symbol, "success"} = 0;
            $info {$symbol, "errormsg"} = "Error retreiving $symbol ";
        }
    }

    return %info if wantarray;
    return \%info;
} 

1; 

=head1 NAME

Finance::Quote::BMONesbittBurns Obtain quotes from the BMO NesbittBurns site

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("bmonesbittburns","NT,X");

=head1 DESCRIPTION

This module fetches information from the "BMO NesbittBurns Quitre Qote" site.
Most Canadiam and US stocks as well as Canadian Mutual Funds are available.

The symbolm representing a stock or mutual fund is composed of the stock
symbol, a comma, and then the index or type. The following indexes and types
are supported:

  T    Toronto Stock Exchange
  MF   Canadian Mutaul Fund
  V    Canadian venture Exchange
  I    Index
  X    U.S Stocks (most exchanges)

This module is loaded by default on a Finance::Quote object. It's 
also possible to load it explicity by placing "BMONesbittBurns" in the argument
list to Finance::Quote->new().

Information obtained by this module may be covered by BMO Nesbitt Burns 
terms and conditions. See http://bmonesbittburns.com/ for details.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::BMONesbittBurns :
name, last, date, p_change, bid, offer, open, high, low,  
volume, currency, method, exchange, time, date.

=head1 SEE ALSO

BMO Nesbitt-Burns  http://bmonesbittburns.com/QuickQuote/QuickQuote.asp
=cut

