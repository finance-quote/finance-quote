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

use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;

our $VERSION = '2.00';

# URLs of where to obtain information

my $AEX_URL = 'http://www.aex.nl/scripts/pop/kb.asp?taal=en';
my $AEXOPT_URL = 'http://www.aex.nl/scripts/marktinfo/OptieKoersen.asp?taal=en';
my $AEXOPT_FRAME_HREF = "/scripts/marktinfo/OptieFrame.asp";
my $AEXOPT_SUBFRAME_URL = "http://www.aex.nl/scripts/marktinfo/ShowOptie.asp?taal=en";
my $AEXFUT_URL = 'http://www.aex.nl/scripts/marktinfo/Futures.asp?taal=en';

# Undocumented features:
# 
# $AEXOPT_FULL:
# 1 - download and search all traded options for a given underlying
# 0 - download and search only most active options (faster but some options are not visible)
our $AEXOPT_FULL = 1;
#
# %AEXOPT_SUBFRAMES_CACHE: Cache made global to allow advanced clients to flush it
our %AEXOPT_SUBFRAMES_CACHE = ();

sub methods { return (dutch       => \&aex,
                      aex         => \&aex,
                      aex_options => \&aex_options,
                      aex_futures => \&aex_futures) } 

{
        my @labels = qw/name symbol price last date time p_change bid ask offer open high low close volume currency method exchange/;
        my @opt_labels = qw/name price last date time bid ask open high low close volume oi trade_volume bid_time bid_volume ask_time ask_volume currency method exchange/;
	my @fut_labels = qw/name price last date time change bid ask open high low close volume currency method exchange/;

        sub labels { return (dutch       => \@labels,
                             aex         => \@labels,
                             aex_options => \@opt_labels,
                             aex_futures => \@fut_labels); } 
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
    $aex_webtickers{uc $_[0]} || $_[0];
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
            $info {$symbol, "symbol"} = uc $symbol;
            $info {$symbol, "exchange"} = "Euronext Amsterdam Stock Markets";
            $info {$symbol, "method"} = "aex";
            $info {$symbol, "name"} = $symbol;
            ($info {$symbol, "last"} = $rows[0][0]) =~ tr/0-9.//cd;   # Remove garbage
            ($info {$symbol, "bid"} = $rows[1][0]) =~ tr/0-9.//cd;
            ($info {$symbol, "ask"} = $rows[2][0]) =~ tr/0-9.//cd;
            ($info {$symbol, "high"} = $rows[3][0]) =~ tr/0-9.//cd;
            ($info {$symbol, "low"} = $rows[4][0]) =~ tr/0-9.//cd;
            ($info {$symbol, "open"} = $rows[5][0]) =~ tr/0-9.//cd;
            ($info {$symbol, "close"} = $rows[6][0]) =~ tr/0-9.//cd;
            ($info {$symbol, "p_change"} = $rows[7][1]) =~ tr/-0-9.%//cd;
            ($info {$symbol, "volume"} = $rows[0][2]) =~ tr/0-9.//cd;

            # Split the date and time from one table entity 
            ($info {$symbol, "date"} = $rows[0][1]) =~ s/\d{2}:\d{2}//;
            ($info {$symbol, "time"} = $rows[0][1]) =~ s/\d{2}\s\w{3}\s\d{4}\s//;

            # Remove spaces at the front and back of the date 
            $info {$symbol, "date"} =~ s/^\s+|\s+$//g;
            $info {$symbol, "time"} =~ s/\s//g;

            # convert date from Dutch (dd mmm yyyy) to US format (mmm/dd/yyyy)
            my @date = split / /, $info {$symbol, "date"};
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

# Input list should be a list of symbols in a form of
# 'AEX C JAN 2004 300.00' (case-insensitive)
# or just 'AEX' which fetches all options for the given underlying symbol
#
# There are two ways to get option data:
# 1. All options from one page
#    Advantages: just one http fetch per one underlying
#    Disadvantages: no volume, no open interest, parsing takes long
# 2. Each option data from a separate subframe
#    Advantages: all data (volume, oi); quick parse
#    Disadvantages: many fetches if many options requested; cannot be done as first;
#    date label unavailable
#
# Especially the last disadvantage is important: to get the address of the subframe,
# the main frame has to be fetched and parsed.
#
# The algorithm below uses the first possibility when all options for a given underlying
# are requested, and the second, when individual options are requested.
# To speed up the second, a cache of urls of subframes is maintained

sub aex_options {
    my $quoter = shift;
    my @symbols = @_;
    my %info;                   # return hash
    return unless @symbols;

    # we allow ambiguous input: both underlyings and individual options
    # so we need to collect a list of all underlyings needed for which
    # main pages have to be fetched.  This is needed when:
    # 1. Explicity underlying is requested;
    # 2. Explicit option is not known in subframes cache
    my @underlyings = grep { /^\w+$/ || !defined($AEXOPT_SUBFRAMES_CACHE{uc $_}) } @symbols;

    # Extract underlying names from this list
    @underlyings = map { uc($_) =~ /^(\w+)/ } @underlyings;

    # we remove the duplicates from @underlyings
    { my %seen; @underlyings = grep { !$seen{$_}++ } @underlyings; }

    # %lookup will allow quick check whether a given symbol is requested
    my %lookup;
    $lookup{uc $_} = $_ foreach (@symbols);

    my $ua = $quoter->user_agent;
    $ua->agent('Mozilla/5.0');          # otherwise AEX IIS breaks down

    foreach my $underlying (@underlyings) {

        my $req = HTTP::Request->new(GET => $AEXOPT_URL . "&a=" . $AEXOPT_FULL . "&Symbool=" . $underlying);
        my $reply = $ua->request($req);

        # get and convert date from Dutch (dd mmm yyyy) to US format (mmm/dd/yyyy)
        my ($date) = $reply->content =~ m[<OPTION\s+SELECTED>(.*?)</OPTION>]mi;
        my $dateusa = join "/", (split /\s/, $date)[1,0,2];

        unless ($reply->is_success && $date) {
            foreach (grep /^$underlying(\s+[CP]\b)?/i, @symbols) {
                $info {$_, "success"} = 0;
                $info {$_, "errormsg"} = "Error retrieving options for underlying $underlying";
            }
            next;
        }

        cache_subframes( $underlying, $reply->content );

        if ( defined($lookup{$underlying}) ) {
            # main page is parsed only when all options are requested
            # (otherwise it has been fetched only to collect subframes hrefs)

            #print STDERR $reply->content,"\n";
            my $te = new HTML::TableExtract( depth => 1, count => 0 );
            $te->parse($reply->content);

            my @options;   # list collecting all existing series

            foreach my $row ($te->rows) {
                my $series = uc $row->[9];

                # skip column headings; we assume that AEX will not change the order
                next if $series =~ /SERIES/; 

                # normalize option name: convert YY to YYYY if needed
                $series =~ s/^(\w+)\s(\d{2}\s.*)$/$1 20$2/;
                # remove commas from strike prices
                $series =~ tr/,//d;

                local *parse_option = sub {
                    my ($type, $pos) = @_;
                    my $symbol = "$underlying $type $series";
                    push  @options, $symbol;
                    #print "   ", join(',', @$row), "\n";

                    # explicitly requested options will be fetched from subframes later
                    # so skipping them here
                    $info {$symbol, "success"} = 1 if !defined $lookup{$symbol};

                    $info {$symbol, "exchange"} = "Euronext Amsterdam Derivative Markets";
                    $info {$symbol, "method"} = "aex_options";
                    $info {$symbol, "name"} = "$underlying $type $series";
                    foreach my $label (qw/close open high low last time bid ask/) {
                        ($info {$symbol, $label} = $row->[$pos++]) =~ tr/0-9.://cd; # Remove garbage
                        undef $info {$symbol, $label} if $info {$symbol, $label} eq "";
                    }
                    $info {$symbol, "date"} = $dateusa;
                    $info {$symbol, "currency"} = "EUR";
                    $info {$symbol, "price"} = $info {$symbol, "last"};
                };

                parse_option("C", 1);
                parse_option("P", 11);

            } # foreach $row

            # if the underlying is explicitly requested, "success" has to be reported properly
            if (@options) {
                $info {$lookup{$underlying}, "success"} = 1;
            } else {
                $info {$lookup{$underlying}, "success"} = 0;
                $info {$lookup{$underlying}, "errormsg"} = "No options found for underlying $underlying";
            }

            # handy extension of the standard F::Q rules: list of all existing options series
            # per underlying
            $info { $lookup{$underlying}, "options"} = \@options;

        } # if defined $lookup{$underlying}

    } # foreach $undelying

    # fetch explict options from subframes
    foreach my $symbol (@symbols) {
        if (!defined ($info {$symbol, "success"}) ) {

            unless (defined $AEXOPT_SUBFRAMES_CACHE{uc $symbol} ) {
                $info {$symbol, "success"} = 0;
                $info {$symbol, "errormsg"} = "Option series not found";
                next;
            }

            my ($underlying, $type, $series) = uc($symbol) =~ /^(\w+) ([CP]) (.*)/;

            # we request always call and put together
            my $req = HTTP::Request->new(GET => $AEXOPT_SUBFRAME_URL . 
                "&C=" . $AEXOPT_SUBFRAMES_CACHE{"$underlying C $series"} .
                "&P=" . $AEXOPT_SUBFRAMES_CACHE{"$underlying P $series"} );
            my $reply = $ua->request($req);

            unless ($reply->is_success) {
                $info {$symbol, "success"} = 0;
                $info {$symbol, "errormsg"} = "Error retrieving option $symbol";
                next;
            }

            #print STDERR $reply->content,"\n";
            my $te = new HTML::TableExtract( depth => 0, count => 0 );
            $te->parse($reply->content);

            local *parse_option = sub {
                my ($type, $col, $symbol) = @_;

                return if !defined $symbol;

                $info {$symbol, "success"} = 1;
                $info {$symbol, "exchange"} = "Amsterdam Euronext eXchange";
                $info {$symbol, "method"} = "aex_options";
                $info {$symbol, "name"} = "$underlying $type $series";
                $info {$symbol, "currency"} = "EUR";

                foreach my $row ($te->rows) {
                    $_ = $row->[0];

                    # standard labels
                    $info {$symbol, 'close'} = $row->[$col]   if /^Vorig Slot/;
                    $info {$symbol, 'open'}  = $row->[$col]   if /^OpenKoers/;
                    $info {$symbol, 'high'}  = $row->[$col]   if /^HoogsteKoers/;
                    $info {$symbol, 'low'}   = $row->[$col]   if /^LaagsteKoers/;
                    $info {$symbol, 'last'}  = $row->[$col]   if /^LaatsteKoers/;
                    $info {$symbol, 'time'}  = $row->[$col+1] if /^LaatsteKoers/;
                    $info {$symbol, 'bid'}   = $row->[$col]   if /^BiedKoers/;
                    $info {$symbol, 'ask'}   = $row->[$col]   if /^LaatKoers/;

                    # additional labels
                    $info {$symbol, 'volume'}       = $row->[$col+2] if /^Naam/;
                    $info {$symbol, 'oi'}           = $row->[$col]   if /^Open Interest/;
                    $info {$symbol, 'trade_volume'} = $row->[$col+2] if /^LaatsteKoers/;
                    $info {$symbol, 'bid_time'}     = $row->[$col+1] if /^BiedKoers/;
                    $info {$symbol, 'bid_volume'}   = $row->[$col+2] if /^BiedKoers/;
                    $info {$symbol, 'ask_time'}     = $row->[$col+1] if /^LaatKoers/;
                    $info {$symbol, 'ask_volume'}   = $row->[$col+2] if /^LaatKoers/;
                }

                # remove garbage
                foreach my $label (qw/close open high low last time bid ask 
                    volume oi trade_volume bid_time bid_volume ask_time ask_volume/)
                {
                    if (defined $info {$symbol, $label}) {
                        $info {$symbol, $label} =~ tr/0-9.://cd;
                        undef $info {$symbol, $label} if $info {$symbol, $label} eq "";
                    }
                }
                $info {$symbol, "price"} = $info {$symbol, "last"};
            };

            parse_option("C", 1, $lookup{"$underlying C $series"});
            parse_option("P", 4, $lookup{"$underlying P $series"});
        }

    } # foreach $symbol

    return wantarray? %info : \%info;
}

# cache_subframes: update $AEXOPT_SUBFRAMES_CACHE 
# with the collected reference numbers for calls and puts
#
sub cache_subframes {
    my $underlying = shift;
    my @subframes = $_[0] =~ m[<A\s+HREF="$AEXOPT_FRAME_HREF.*?&c=(\d+)&p=(\d+)".*?>(.*?)</A>]sigo;

    while (@subframes) {
        # @subframes contains n*3 elements
        my $callref = shift @subframes;
        my $putref = shift @subframes;
        my $series = uc shift @subframes;  # fromat like "Oct 07 1,000.00"

        # normalize option name: convert YY to YYYY if needed
        $series =~ s/^(\w+)\s(\d{2}\s.*)$/$1 20$2/;

        # remove commas from strike prices
        $series =~ tr/,//d;

        $AEXOPT_SUBFRAMES_CACHE{"$underlying C $series"} = $callref;
        $AEXOPT_SUBFRAMES_CACHE{"$underlying P $series"} = $putref;
    }
}



########################################################################
# Input list should be a list of symbols in a form of
# 'FTI JAN 2004' (case-insensitive)
# or just 'FTI' which fetches all futures series
#

sub aex_futures {
    my $quoter = shift;
    my @symbols = @_;
    my %info;                   # return hash
    return unless @symbols;

    # we allow ambiguous input: both futures symbols and individual futures series
    # so we need to collect a pure list of all futures needed
    my @futures = map { uc($_) =~ /^(\w+)/ } @symbols;

    # we remove the duplicates from @futures
    { my %seen; @futures = grep { !$seen{$_}++ } @futures; }

    # %lookup will allow quick check whether a given symbol is requested
    my %lookup;
    $lookup{uc $_} = $_ foreach (@symbols);

    my $ua = $quoter->user_agent;
    $ua->agent('Mozilla/5.0');          # otherwise AEX IIS breaks down

    foreach my $future (@futures) {

        my $req = HTTP::Request->new(GET => $AEXFUT_URL . "&symbool=" . $future);
        my $reply = $ua->request($req);
        my ($date) = $reply->content =~ m[$future Futures at (.*?)<BR>]mi;

        unless ($reply->is_success && $date) {
            foreach (grep /^$future\b/i, @symbols) {
                $info {$_, "success"} = 0;
                $info {$_, "errormsg"} = "Error retrieving futures $future";
            }
            next;
        }

        # convert date from Dutch (dd mmm yyyy) to US format (mmm/dd/yyyy)
        my $dateusa = join "/", (split /\s/, $date)[1,0,2];

        #print STDERR $reply->content,"\n";
        my $te = new HTML::TableExtract(
            headers => ['Stock','Current','Dif.','Date / Time','Bid','Ask','Volume','High','Low','Open']
        );
        $te->parse($reply->content);

        my @all_futures;
        foreach my $row ($te->rows) {
            (my $series = uc $row->[0]) =~ s/\s+$//; # get rid of trailing spaces immediately

            # normalize future series name: convert YY to YYYY if needed
            $series =~ s/^(\w+)\s(\d{2})$/$1 20$2/;

            my $symbol = $lookup{"$future $series"};
            if ($lookup{$future} || $symbol) {
                #print "   ", join(',', @$row), "\n";
                $symbol ||= "$future $series";
                push  @all_futures, $symbol;

                $info {$symbol, "success"} = 1;
                $info {$symbol, "exchange"} = "Euronext Amsterdam Derivative Markets";
                $info {$symbol, "method"} = "aex_futures";
                $info {$symbol, "name"} = "$future $series";
                my $pos = 1;
                foreach my $label (qw/last change time bid ask volume high low open/) {
                    ($info {$symbol, $label} = $row->[$pos++]) =~ tr/-0-9.://cd; # Remove garbage
                    undef $info {$symbol, $label} if $info {$symbol, $label} eq "";
                }
                $info {$symbol, "close"} = $info {$symbol, "last"} - ($info {$symbol, "change"} || 0);
                $info {$symbol, "date"} = $dateusa;
                $info {$symbol, "currency"} = "EUR";
                $info {$symbol, "price"} = $info {$symbol, "last"};
            }

        }

        # if all futures are explicitly requested, "success" has to be reported properly
        if ($lookup{$future}) {
            if (@all_futures) {
                $info {$lookup{$future}, "success"} = 1;
                # handy extension of the standard F::Q rules: list of all collected series
                # per future symbol
                $info { $lookup{$future}, "futures"} = \@all_futures;
            } else {
                $info {$lookup{$future}, "success"} = 0;
                $info {$lookup{$future}, "errormsg"} = "Error retrieving futures $future";
            }
        }

    } # foreach $future 

    return wantarray? %info : \%info;
}


1;

=head1 NAME

Finance::Quote::AEX	- Obtain stocks and options quotes from Euronext Amsterdam exchange

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    # Only query AEX
    %info = Finance::Quote->fetch("aex","asml");

    # Failover to other sources OK. 
    %info = Finance::Quote->fetch("dutch","phi");

    # Fetch specific option
    %info = Finance::Quote->fetch("aex_options","phi c oct 2007 20.00");

    # Fetch all options in PHI
    %info = Finance::Quote->fetch("aex_options","phi");

    # Fetch future in AEX
    %info = Finance::Quote->fetch("aex_futures","fti oct 2003");

=head1 DESCRIPTION

This module fetches information from the Euronext Amsterdam,
http://www.aex.nl (previously called Amsterdam Exchange). All Dutch
stocks, options, futures, and indices are available.

This module is loaded by default on a Finance::Quote object. It is 
also possible to load it explicity by placing "AEX" in the argument
list to Finance::Quote->new().

Information obtained by this module may be covered by www.aex.nl 
terms and conditions See http://www.aex.nl/ for details.

=head2 Stocks And Indices

This module provides both the "aex" and "dutch" fetch methods for fetching
stock and index quotes.  Please use the "dutch" fetch method if you wish
to have failover with future sources for Dutch stocks. Using the "aex"
method will guarantee that your information only comes from the Euronext
Amsterdam website.

=head2 Options

To fetch stock or index options quotes, use the "aex_options" method.
Specifying which option to fetch can be done in two ways: naming the
underlying value, or naming a specific option.  In the first case, all
tradable options for the given underlying will be returned.  In the second
case, only the requested options will be returned.  When naming an option,
use a string consisting of the following single-space-separated fields
(case insensitive):

    <underlying symbol>
    <call (C) or put (P) letter>
    <three-letter expiration month>
    <four-digit expiration year>
    <strike price, including decimal point>

Example: "PHI C OCT 2007 20.00" is a call option in Philips, expiration
month October 2007, strike price 20.00 euro.

Since options series come and go (options expire, new option series start
being traded), a special label 'options' returns a list of all options
found (fetched) for a given underlying.  This label is only present for
the underlyings (if requested).

When fetching individual options, more labels are returned (see below),
because in such case option data is fetched from a subframe. When this is
not relevant, the following trade-off may be considered: when fetching
options for a given underlying, all options are returned, what may take
up to 30s for 300 options (e.g for AEX Index); when fetching individual
options, it takes ca 0.5s per option (on Pentium 75Mhz).

=head2 Futures

To fetch futures quotes in stocks or indices, use the "aex_futures"
method.  Specifying which option to fetch can be done in two ways,
similarly to options: providing the futures symbol, or naming a specific
futures series.  In the first case, all tradable futures series will
be returned.  In the second case, only the requested futures will be
returned.  When naming a specific futures series use a string consisting
of the following single-space-separated fields (case insensitive):

    <futures symbol>
    <three-letter expiration month>
    <four-digit expiration year>

Example: "FTI OCT 2003" is a futures contract in AEX Index, expiration
month October 2003.

Similarly to options, a special label 'futures' returns a list of all futures
found (fetched) for a given futures symbol.  This label is only present 
for futures symbols requested, not for individual futures.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::AEX "aex" method:
name, symbol, last, price (=last), date, time, p_change, bid, ask, offer
(=ask), open, high, low, close, volume, currency, method, exchange.

The following labels may be returned by Finance::Quote::AEX "aex_options"
method: name, options, last, price (=last), date, time, bid, ask, open,
high, low, close, currency, method, exchange.

The following additional labels may be returned by "aex_options" when 
fetching individual options: volume oi trade_volume bid_time bid_volume 
ask_time ask_volume. In such case label date is not returned.

The following labels may be returned by Finance::Quote::AEX "aex_futures"
method: name, price, last, date, time, change, bid, ask, open, high, low,
close, volume, currency, method, exchange.

=head1 SEE ALSO

Euronext Amsterdam Markets, http://www.aex.nl/aex.asp?taal=en 

=cut

