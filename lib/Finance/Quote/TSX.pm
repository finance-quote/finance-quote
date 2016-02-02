#!/usr/bin/perl -w
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@cpan.org>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#    Copyright (C) 2001, Leigh Wedding <leigh.wedding@telstra.com>
#    Copyright (C) 2006, Mika Laari <mika.laari@iki.fi>
#    Copyright (C) 2008, Emmanuel Rodriguez <potyl@cpan.org>
#    Copyright (C) 2016, Bob Swift <bswift@rsds.ca>
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
# This code derived from the work of Mika Laari in the package
# Finance::Quote::HEX.
#
# This code was developed as part of GnuCash <http://www.gnucash.org/>

require 5.005;

use strict;

package Finance::Quote::TSX;

use LWP::UserAgent;
use HTML::TableExtract;
use URI;
use URI::QueryParam;

# VERSION

# This URL is able to accept up to 10 symbols at a time
my $TSX_URL = 'http://web.tmxmoney.com/getquote.php';
my $param = 'symbols[]=';

# Example URL for multiple quotes: 'http://web.tmxmoney.com/getquote.php?symbols[]=stn&symbols[]=ap.un&symbols[]=pca002&symbols[]=tsx&symbols[]=notvalid';
#                                                                                   ^               ^               ^              ^               ^
#                                                                                 Stock           Stock            Fund          Index         (invalid)

# The number of symbols that can be fetched at a time per URL
my $BATCH_SIZE = 10;

my @LABELS = qw(name last date time net p_change volume exchange currency symbol);

# Symbol Map
my %symbolmap = ();


sub methods {
	return (
		tsx    => \&tsx,
		canada => \&tsx,
	);
}

sub labels {
	return (
		tsx    => \@LABELS,
		canada => \@LABELS,
	);
}


# Toronto Stock Exchange (TSX)
# The TSX provides free delayed quotes through their webpage.
# This module is based on HEX.pm.
#
# Maintainer of this section is Emmanuel Rodriguez <potyl@cpan.org>.

sub tsx {
	my $quoter = shift;
	my @symbols = @_;
	return unless @symbols;
    
    # Save a copy of the symbols list for later checking
    my @save_symbols = @symbols;

    # Symbols returned on the web site are all upper case regardless of the case searched,
    # so we create a map of the symbols input to the search to an upper case version of
    # the symbol.  The original search symbol will be used as the key in the hash returned.
    %symbolmap = map { uc($_) => $_ } @symbols;
	my %info = ();

	# Fetch the stocks per batch
	while (@symbols) {

		# Get the next batch of symbols
		my @batch = splice @symbols, 0, $BATCH_SIZE;

		# Build the URL
		my $url = $TSX_URL . '?' . $param . join('&' . $param, @batch);

		# Download the stock information
		my $response = $quoter->user_agent->get($url);
		unless ($response->is_success) {
			foreach my $symbol (@batch) {
				$info{$symbol, 'success'} = 0;
				$info{$symbol, 'errormsg'} = "HTTP session failed";
			}
			next;
		}

		# Extract the stock information
		extract_stock_data(\%info, $response->content);
	}

	# Make sure that all symbols were found
    # and clean up date and time information.
	foreach my $symbol (@save_symbols) {
        if ((defined $info{$symbol,"date"}) && ($info{$symbol,"date"} ne "")) {
            $quoter->store_date(\%info, $symbol, {usdate => $info{$symbol,"date"}}); }
        if ((defined $info{$symbol,"time"}) && ($info{$symbol,"time"} ne "")) {
            $info{$symbol, "time"} = $quoter->isoTime($info{$symbol,"time"}); }
        next if exists $info{$symbol, 'name'};
		$info{$symbol, 'success'} = 0;
		$info{$symbol, 'errormsg'} = "Symbol not found";
	}
    
	return wantarray() ? %info : \%info;
}


#
# Extracts the stock data from an HTML page.
#
# Returns a list of symbol structs.
#
sub extract_stock_data {

	my ($info, $content) = @_;

    # Get the dates for Stocks and Funds because they appear in different tables.
    # Get the dates for Indices if the Stocks table is missing.  Stocks dates and
    # Indices dates are shown as the same on the web page returned from a search.
    # Use Stocks dates by default for everything except Funds.
    my ($s_date, $s_time) = getdate('Stocks', $content);
    my ($f_date, $f_time) = getdate('Funds', $content);
    if ($s_date eq "") { ($s_date, $s_time) = getdate('Indices', $content); }
    
	# The stocks, funds and indices are in separate tables of <table class="tablemaster">
    # thus we need to check three counts of the table to catch everything.
	# NOTE: TSX returns extra symbols who's names are similar to the symbols that
	#       are going to be fetched. This method will exclude such symbols.
    my $counter = 0;
    while ($counter < 3) {
        my $parser = HTML::TableExtract->new(count => $counter++, attribs => { class => 'tablemaster' } );
        $parser->parse($content);
    
        my ($table) = $parser->tables;
        return unless defined $table;
    
        my $is_header = 1;
        foreach my $row ($table->rows) {
    
            # Skip the header
            if ($is_header) {
                $is_header = 0;
                next;
            }
    
            # Initialize field counter
            my $i = 0;
            
            # Parse the symbol, and compare to symbol map
            my $symbolread = uc($row->[$i++]);
            my $symbol = $symbolread;
            if (exists $symbolmap{$symbol}) { $symbol = $symbolmap{$symbol}; }
    
            # Parse the name and last price
            my $name = $row->[$i++];
            my $last = $row->[$i++];
            $last =~ s/^\s*//;
            if ($last eq "") { $last = 0; }
            
            # Skip if not a valid symbol
            next unless ((defined $name) && ($name ne "") && ($last > 0));
            
            # Set currency based on ":US" extension to symbol
            my $currency = 'CAD';
            if ($symbol =~ m/:US$/i) { $currency = 'USD'; }
            $info->{$symbol, 'currency'} = $currency;
    
            # Set exchange based on lack of ":US" extension to symbol
            my $exchange = 'T';
            if ($symbol =~ m/:US$/i) { $exchange = ''; }
            $info->{$symbol, 'exchange'} = $exchange;
    
            # Save previously parsed field information and parse the other fields
            $info->{$symbol, 'symbol'} = $symbolread;
            $info->{$symbol, 'name'} = $name;
            $info->{$symbol, 'last'} = $last;
            # The change is in the format '-0.40 (-0.5%)' (positive numbers have no sign)
            if ($row->[$i++] =~ /(-?\d+\.\d+) \s+ \((-?\d+\.\d+)%\)/x) {
                $info->{$symbol, 'net'} = $1;
                $info->{$symbol, 'p_change'} = $2;
            }
            my $volume = $row->[$i++];
            if ((not defined $volume) or ($volume eq "")) {
                # Use Funds date and time
                $info->{$symbol, 'date'} = $f_date;
                $info->{$symbol, 'time'} = $f_time;
                $volume = 0;
            } else {
                # Use Stocks date and time
                $info->{$symbol, 'date'} = $s_date;
                $info->{$symbol, 'time'} = $s_time;
            }
            $info->{$symbol, 'volume'} = $volume;
            
            # Cleanup
            $info->{$symbol, 'volume'} =~ s/,//g;
            $info->{$symbol, 'method'} = 'tsx';
            $info->{$symbol, 'success'} = 1;
        }
    }
}


# Parse date and time information and return in standard format for later processing
sub getdate {
	my ($dtype, $content) = @_;
    my ($datetime) = ($content =~ m/>$dtype<[^>]+.[^>]+.([^<]*)/i);
    unless ((defined $datetime) && ($datetime ne "")) { return ("", ""); }
    $datetime =~ s/,//g;
    my ($mo, $da, $yr, $tm) = ($datetime =~ m/^\s*(\S+)\s+(\S+)\s+(\S+)\s+(.*)\s*$/);
    my $dt = sprintf("%s %u %u", $mo, $da, $yr);
    return ($dt, $tm);
}


1;

=head1 NAME

Finance::Quote::TSX	- Obtain quotes from the Toronto Stock Exchange.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %stockinfo = $q->fetch("tsx","BCE");    # Only query TSX.
    %stockinfo = $q->fetch("canada","BCE"); # Failover to other sources OK.

=head1 DESCRIPTION

This module obtains information from the Toronto Stock Exchange
through the page http://web.TMXmoney.com/.

This module is not loaded by default on a Finance::Quote object.
It's possible to load it explicity by placing "TSX" in the argument
list to Finance::Quote->new().

This module provides both the "tsx" and "canada" fetch methods.
Please use the "canada" fetch method if you wish to have failover with other
sources for Canadian stocks.  Using the "tsx" method will guarantee that your
information only comes from the Toronto Stock Exchange.

=head1 LABELS RETURNED

The following labels are returned by Finance::Quote::TSX:
name, last, date, time, net, p_change, volume, and exchange,
plus two additional custom labels currency and symbol.

This module returns less information (labels) than other sources but it's able
to retrieve them faster because each HTTP request performed can return up to 10
stocks. Thus, if the labels provided by this module are sufficient for your
application then you should give it a try.

=head1 SEE ALSO

Toronto Stock Exchange, http://www.TMXmoney.com/

=cut
