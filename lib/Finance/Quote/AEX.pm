#!/usr/bin/perl -w
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@Acpan.org>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#    Copyright (C) 2001, Rob Sessink <rob_ses@users.sourceforge.net>
#    Copyright (C) 2003, Pawel Konieczny <konieczp@users.sourceforge.net>
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

use vars qw($VERSION $AEX_URL $AEXOPT_URL $AEXOPT_FULL); 

use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;

$VERSION = '1.5';

# URLs of where to obtain information

my $AEX_URL = 'http://www.aex.nl/scripts/pop/kb.asp?taal=en';
my $AEXOPT_URL = 'http://www.aex.nl/scripts/marktinfo/OptieKoersen.asp?taal=en';

# Undocumented features:
# 
# $AEXOPT_FULL:
# 1 - download and search all traded options for a given underlying
# 0 - download and search only most active options (faster but some options are not visible)
our $AEXOPT_FULL = 1;

sub methods { return (dutch       => \&aex,
                      aex         => \&aex,
                      aex_options => \&aex_options) } 

{
        my @labels = qw/name symbol price last date time p_change bid ask offer open high low close volume currency method exchange/;
        my @opt_labels = qw/name options price last date time bid ask open high low close currency method exchange/;

        sub labels { return (dutch       => \@labels,
                             aex         => \@labels,
                             aex_options => \@opt_labels); } 
}

# ==============================================================================


# Some ticker symbols have to be translated to a different symbol for fetch() call
# The problem is that the AEX url does not (not always) use the official ticker
# to their CGI query 
# The list is complete for Big Caps and Mid Caps as on 29-Jun-2003

sub aex_webticker {
    my %aex_webtickers = (
        'DRAK', 'DRAKA',
        'ORDI', 'ORDINA',
        'VRSA', 'VTEL',
        'REN',  'ELS',
        'ASM',  'ASIN',
        'AMX',  'MIDKAP',
        'FUR',  'FUGRO',
        'AMST', 'AMSTL',
        'FORA', 'FOR',
        'LOG',  'CMG',
        'BOKA', 'BOSK',
        'CORA', 'VIB',
        'UNTS', 'UNIQ',
        'WH',   'WB',
        'RASA', 'RASAA',
        'VAST', 'VASTN',
    );
    $aex_webtickers{uc $_[0]} ? $aex_webtickers{uc $_[0]} : $_[0];
}


# Indices are not quoted in euro but in points
# The following function detects whether a given symbol is an index

sub is_index {
    my %indices = ( AEX => 1, AMX => 1, MIDKAP => 1 );

    return defined $indices{uc $_[0]};
}

########################################################################
# Stocks and indices

sub aex {
    my $quoter = shift;
    my @symbols = @_;
    return unless @symbols;

    my (%info,$url,$reply,$te);
    my ($row, $datarow, $matches);

    my $ua = $quoter->user_agent;       # user_agent
    $url = $AEX_URL;                    # base url 

    foreach my $symbol (@symbols) {

        my $websymbol = aex_webticker($symbol); 
        $reply = $ua->request(GET $url.join('',"&alf=",$websymbol)); 

        if ($reply->is_success) { 

            #print STDERR $reply->content,"\n";

            $te = new HTML::TableExtract( headers => [("Stock","Time","Volume")]);

            # parse table
            $te->parse($reply->content); 

            # check for a page without tables.
            # This gets returned when a bad symbol name is given.
            unless ( $te->tables ) 
            {
                $info {$symbol,"succes"} = 0;
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

            $info {$symbol, "success"} = 1;
            $info {$symbol, "symbol"} = $symbol;
            $info {$symbol, "exchange"} = "Amsterdam Euronext eXchange";
            $info {$symbol, "method"} = "aex";
            $info {$symbol, "name"} = $symbol;
            ($info {$symbol, "last"} = $rows[0][0]) =~ s/[^\d\.]*//g; # Remove garbage
            ($info {$symbol, "bid"} = $rows[1][0]) =~ s/[^\d\.]*//g; 
            ($info {$symbol, "ask"} = $rows[2][0]) =~ s/[^\d\.]*//g;
            ($info {$symbol, "high"} = $rows[3][0]) =~ s/[^\d\.]*//g; 
            ($info {$symbol, "low"} = $rows[4][0]) =~ s/[^\d\.]*//g;
            ($info {$symbol, "open"} = $rows[5][0]) =~ s/[^\d\.]*//g;
            ($info {$symbol, "close"} = $rows[6][0]) =~ s/[^\d\.]*//g;
            ($info {$symbol, "p_change"} = $rows[7][1]) =~ s/[^\d\.\-\%]*//g;
            ($info {$symbol, "volume"} = $rows[0][2]) =~ s/[^\d\.]*//g;

            # Split the date and time from one table entity 
            ($info {$symbol, "date"} = $rows[0][1]) =~ s/\d{2}:\d{2}//;  
            ($info {$symbol, "time"} = $rows[0][1]) =~ s/\d{2}\s\w{3}\s\d{4}\s//;

            # Remove spaces at the front and back of the date 
            $info {$symbol, "date"} =~ s/^\s*|\s*$//g;
            $info {$symbol, "time"} =~ s/\s*//g;

            # convert date from Dutch (dd mmm yyyy) to US format (mmm/dd/yyyy)
            my @date = split /\s/, $info {$symbol, "date"};
            $info {$symbol, "date"} = $date[1]."/".$date[0]."/".$date[2]; 

            $info {$symbol, "currency"} = "EUR" unless is_index($symbol);

            # adding some legacy labels
            $info {$symbol, "offer"} = $info {$symbol, "ask"};
            $info {$symbol, "price"} = $info {$symbol, "last"};

            # convert "no-data" fields to undefs
            foreach my $label (qw/price last bid ask high low open close p_change volume date time offer/) {
                undef $info {$symbol, $label} if $info {$symbol, $label} eq "";
            }

            $info {$symbol, "success"} = 1; 
        } else {
            $info {$symbol, "success"} = 0;
            $info {$symbol, "errormsg"} = "Error retreiving $symbol";
        }
    } 

    return wantarray? %info : \%info;
} 


########################################################################
# Options

sub aex_options {
    my $quoter = shift;
    my @symbols = @_;
    my %info;                   # return hash
    return unless @symbols;

    # we allow ambiguous input: both underlyings and individual options
    # so we need to collect a pure list of all underlyings needed
    my @underlyings = map { uc($_) =~ /(\w+)/; } @symbols;

    # we remove the duplicates from @underlyings
    my %grep;
    @underlyings = grep { !$grep{$_}++; } @underlyings;
 
    # %lookup will allow quick check whether a given symbol is requested
    my %lookup;
    foreach (@symbols) { $lookup{uc($_)} = $_; }
    
    my $ua = $quoter->user_agent;
    $ua->agent('Mozilla/5.0');          # otherwise AEX IIS breaks down
    
    foreach my $underlying (@underlyings) {

        my $req = HTTP::Request->new(GET => $AEXOPT_URL . "&a=" . $AEXOPT_FULL . "&Symbool=" . $underlying);
        my $reply = $ua->request($req);
        my ($date) = $reply->content =~ m[<OPTION\s+SELECTED>(.*?)</OPTION>]mi;

        unless ($reply->is_success && $date) { 
            foreach (grep /$underlying\s+([CP]\b)?/i, @symbols) {
                $info {$_, "success"} = 0;
                $info {$_, "errormsg"} = "Error retrieving options for underlying $underlying";
            }
            next;
        }
      
        # convert date from Dutch (dd mmm yyyy) to US format (mmm/dd/yyyy)
        my $dateusa = join "/", (split /\s/, $date)[1,0,2];
            
        #print STDERR $reply->content,"\n";
        my $te = new HTML::TableExtract( depth => 1, count => 0 );
        $te->parse($reply->content); 
        
        my @options;
        foreach my $row ($te->rows) {
            my $series = uc $row->[9];

            # skip column headings; we assume that AEX will not change the order
            next if $series =~ /SERIES/; 

            # normalize option name: convert YY to YYYY if needed
            $series =~ s/^(\w+)\s(\d{2}\s.*)$/$1 20$2/;

            # remove commas from strike prices
            $series =~ tr/,//d;

            # full option symbol
            my $symbol;

            # Call
            $symbol = $lookup{"$underlying C $series"};
            if ($lookup{$underlying} || $symbol) {
                #print "   ", join(',', @$row), "\n";
                $symbol = "$underlying C $series" unless $symbol;
                push  @options, $symbol;

                $info {$symbol, "success"} = 1;
                $info {$symbol, "exchange"} = "Amsterdam Euronext eXchange";
                $info {$symbol, "method"} = "aex_options";
                $info {$symbol, "name"} = "$underlying C $series";
                my $pos = 1;
                foreach my $label (qw/close open high low last time bid ask/) {
                    ($info {$symbol, $label} = $row->[$pos++]) =~ s/[^\d\.\:]*//g; # Remove garbage
                    undef $info {$symbol, $label} if $info {$symbol, $label} eq "";
                }
                $info {$symbol, "date"} = $dateusa;
                $info {$symbol, "currency"} = "EUR";
                $info {$symbol, "price"} = $info {$symbol, "last"} if defined ($info {$symbol, "last"});
            }
            
            # Put
            $symbol = $lookup{"$underlying P $series"};
            if ($lookup{$underlying} || $symbol) {
                #print "   ", join(',', @$row), "\n";
                $symbol = "$underlying P $series" unless $symbol;
                push  @options, $symbol;

                $info {$symbol, "success"} = 1;
                $info {$symbol, "exchange"} = "Amsterdam Euronext eXchange";
                $info {$symbol, "method"} = "aex_options";
                $info {$symbol, "name"} = "$underlying P $series";
                my $pos = 11;
                foreach my $label (qw/close open high low last time bid ask/) {
                    ($info {$symbol, $label} = $row->[$pos++]) =~ s/[^\d\.\:]*//g; # Remove garbage
                    undef $info {$symbol, $label} if $info {$symbol, $label} eq "";
                }
                $info {$symbol, "date"} = $dateusa;
                $info {$symbol, "currency"} = "EUR";
                $info {$symbol, "price"} = $info {$symbol, "last"} if defined ($info {$symbol, "last"});
            }
        }

        # if the underlying is explicitly requested, "success" has to be reported properly
        if ($lookup{$underlying}) {
            if (@options) {
                $info {$lookup{$underlying}, "success"} = 1;
            } else {
                $info {$lookup{$underlying}, "success"} = 0;
                $info {$lookup{$underlying}, "errormsg"} = "No options found for underlying $underlying";
            }

            # handy extension of the standard F::Q rules: list of all collected options
            # per underlying
            $info { $lookup{$underlying}, "options"} = \@options;
        }

        # find out which options that were explicitly requested are not found
        foreach (grep /$underlying\s+[CP]\b/i, @symbols) {
            unless (defined $info {$_, "success"}) {
                $info {$_, "success"} = 0;
                $info {$_, "errormsg"} = "Option series not found";
            }
        }
    } 

    return wantarray? %info : \%info;
} 

1; 

=head1 NAME

Finance::Quote::AEX Obtain stocks and options quotes from 
Amsterdam Euronext eXchange 

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("aex","asml");  # Only query AEX
    %info = Finance::Quote->fetch("dutch","phi"); # Failover to other sources OK. 
    %info = Finance::Quote->fetch("aex_options","phi c oct 2007 20.00"); # Fetch specific option
    %info = Finance::Quote->fetch("aex_options","phi"); # Fetch all options in PHI

=head1 DESCRIPTION

This module fetches information from the "Amsterdam Euronext
eXchange AEX" http://www.aex.nl. All Dutch stocks, options and indices are
available. 

This module is loaded by default on a Finance::Quote object. It's 
also possible to load it explicity by placing "AEX" in the argument
list to Finance::Quote->new().

This module provides both the "aex" and "dutch" fetch methods for fetching
stock quotes.  Please use the "dutch" fetch method if you wish to have
failover with future sources for Dutch stocks. Using the "aex" method will
guarantee that your information only comes from the Amsterdam Euronext
eXchange.

To fetch stock or index options quotes, use the "aex_options" method.
Specifying which option to fetch can be done in two ways: naming the
underlying value, or naming a specific option.  In the first case, all
tradable options for the given underlying will be returned.  In the second
case, only the requested options will be returned.  When naming an option,
use a string consisting of the following space-separated fields (case
insensitive): 
    <underlying symbol>
    <call (C) or put (P) letter>
    <three-letter expiration month>
    <four-digit expiration year>
    <strike price, including decimal point>

Example: "PHI C OCT 2007 20.00" is a call option in Philips, expiration
month October 2007, strike price 20.00 euro.

Since options series come and go (options expire, new option series start
being traded), a special label 'options' returns a list of all options
found (fetched) for a given underlying.  This label is only present for the
underlyings.

Information obtained by this module may be covered by www.aex.nl 
terms and conditions See http://www.aex.nl/ for details.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::AEX "aex" method:
name, symbol, last, price (=last), date, time, p_change, bid, ask, offer
(=ask), open, high, low, close, volume, currency, method, exchange.

The following labels may be returned by Finance::Quote::AEX "aex_options"
method: name, options, last, price (=last), date, time, bid, ask, open,
high, low, close, currency, method, exchange.

=head1 TO DO

Returning of volume and open interest for options.
Fetching futures quotes.

=head1 SEE ALSO

Amsterdam Euronext eXchange, http://www.aex.nl

=cut

