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

use vars qw/$VERSION/;

$VERSION = '1.15';

# This URL is able to accept up to 10 symbols at a time
my $TSX_URL = URI->new('http://cxa.marketwatch.com/tsx/en/market/getquote.aspx');

# The number of symbols that can be fetched at a time per URL
my $BATCH_SIZE = 10;

my @LABELS = qw(name last net p_change volume exchange);


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

	my %info = ();

	# Fetch the stocks per batch
	while (@symbols) {

		# Get the next batch of symbols
		my @batch = splice @symbols, 0, $BATCH_SIZE;

		# Build the URL
		my $url = $TSX_URL->clone;
		$url->query_param(symb => join ',', @batch);

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


	# Make sure that all symbols where found
	foreach my $symbol (@symbols) {
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

	# The stocks are in <table class="data">
	# NOTE: TSX returns extra symbols who's names are similar to the symbols that
	#       are going to be fetched. This method will exclude such symbols.
	my $parser = HTML::TableExtract->new(attribs => { class => 'data' } );
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

		my $i = 0;
		# The symbol is in the format 'BCE-T' (T is the exchange)
		my $symbol = $row->[$i++];
		if ($symbol =~ s/-(.)$//) {
			$info->{$symbol, 'exchange'} = $1;
		}


		# Parse the other fields
		$info->{$symbol, 'name'} = $row->[$i++];
		$info->{$symbol, 'last'} = $row->[$i++];
		# The change is in the format '-0.40 (-0.5%)' (positive numbers have no sign)
		if ($row->[$i++] =~ /(-?\d+\.\d+) \s+ \((-?\d+\.\d+)%\)/x) {
			$info->{$symbol, 'net'} = $1;
			$info->{$symbol, 'p_change'} = $2;
		}
		$info->{$symbol, 'volume'} = $row->[$i++];


		# Cleanup
		$info->{$symbol, 'volume'} =~ s/,//g;

		$info->{$symbol, 'method'} = 'tsx';
		$info->{$symbol, 'success'} = 1;
	}
}


1;

=head1 NAME

Finance::Quote::TSX	- Obtain quotes from the Toronto Stock Exchange.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %stockinfo = $q->fetch("tsx","NT-T");	  # Only query TSX.
    %stockinfo = $q->fetch("canada","NT");  # Failover to other sources OK.

=head1 DESCRIPTION

This module obtains information from the Toronto Stock Exchange
through the page http://www.TMXmoney.com/.

This module is not loaded by default on a Finance::Quote object.
It's possible to load it explicity by placing "TSX" in the argument
list to Finance::Quote->new().

This module provides both the "tsx" and "toronto" fetch methods.
Please use the "canada" fetch method if you wish to have failover with other
sources for Canadian stocks.  Using the "tsx" method will guarantee that your
information only comes from the Toronto Stock Exchange.

=head1 LABELS RETURNED

The following labels are returned by Finance::Quote::TSX:
name, last, net, p_change, volume and exchange.

This module returns less information (labels) than other sources but it's able
to retrieve them faster because each HTTP request performed can return up to 10
stocks. Thus, if the labels provided by this module are sufficient for your
application then you should give it a try.

=head1 SEE ALSO

Toronto Stock Exchange, http://www.TMXmoney.com/

=cut
