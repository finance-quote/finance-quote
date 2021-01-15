#!/usr/bin/perl -w
#
#	Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#	Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#	Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#	Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#	Copyright (C) 2001, Leigh Wedding <leigh.wedding@telstra.com>
#	Copyright (C) 2000-2004, Paul Fenwick <pjf@cpan.org>
#	Copyright (C) 2014, Chris Good <chris.good@@ozemail.com.au>
#
#	This program is free software; you can redistribute it and/or modify
#	it under the terms of the GNU General Public License as published by
#	the Free Software Foundation; either version 2 of the License, or
#	(at your option) any later version.
#
#	This program is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.
#
#	You should have received a copy of the GNU General Public License
#	along with this program; if not, write to the Free Software
#	Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
#	02110-1301, USA
#
#
# This code derived from Padzensky's work on package Finance::YahooQuote,
# but extends its capabilites to encompas a greater number of data sources.
#
# This code was developed as part of GnuCash <http://www.gnucash.org/>

require 5.005;

use strict;
use warnings;

package Finance::Quote::ASX;

use LWP::UserAgent;
use JSON qw/decode_json/;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use vars qw/$ASX_URL_PRIMARY $ASX_URL_ALTERNATE/;

# VERSION

$ASX_URL_PRIMARY = 'https://www.asx.com.au/asx/1/share/';
$ASX_URL_ALTERNATE = 'https://asx.api.markitdigital.com/asx-research/1.0/companies/';

sub methods {return (australia => \&asx,asx => \&asx)}

{
	my @labels = qw/
			ask
			bid
			cap
			close
			date
			eps
			high
			last
			low
			name
			net
			open
			p_change
			pe
			type
			volume/;

# Function that lists the data items available from the Australian Securities Exchange (ASX)

	sub labels { return (australia => \@labels,
						 asx	   => \@labels); }
}

# Australian Stock Exchange (ASX)
# The ASX provides free delayed quotes through their webpage:
#	https://www2.asx.com.au/markets/company/NAB
#
# Maintainer of this section is Paul Fenwick <pjf@cpan.org>
# 5-May-2001 Updated by Leigh Wedding <leigh.wedding@telstra.com>
# 24-Feb-2014 Updated by Chris Good <chris.good@@ozemail.com.au>
# 12-Oct-2020 Updated by Jeremy Volkening
# Jan-2021 Updated by Geoff <cleanoutmyshed@gmail.com>
#	October 2020 the ASX revamped their website with dynamic content for quotes
#	which prevented the previous HTML screen scraping from working, but exposed
#	a number of JSON data sources, two of which are used here.
#	The primary source returns data elements for almost all securities, but
#	does not return prices for certain security types (some bonds and exchange
#	traded products, options, and warrants), and returns an error for indices.
#	The alternate source returns less data elements, but provides usable quote
#	data for all the known exceptions, including indices.
#	This version will always call the primary source, and call the alternate if
#	a price is not returned by the primary.
#
#	Smart::Comments implemented to conform with the Hackers Guide:
#		https://github.com/finance-quote/finance-quote/blob/master/Documentation/Hackers-Guide
#

# Main function to fetch quotes from the Australian Securities Exchange (ASX)

sub asx {

	my $quoter = shift;
	my @symbols = @_
		or return;

	my($error, %info, $status, $ua);

	$ua = $quoter->user_agent;

	SYMBOL:
	for my $symbol (@symbols) {
### ASX.pm  Processing symbol: $symbol
		$info{ $symbol, 'symbol'   } = $symbol;
		$info{ $symbol, 'method'   } = 'asx';
		$info{ $symbol, 'exchange' } = 'Australian Securities Exchange';

		$symbol =~ s/\s+$//;
		if	($symbol !~ m/^[A-Za-z0-9]{1,6}$/) {
			$info{ $symbol, 'success'  } = 0;
			$info{ $symbol, 'errormsg' } = 'Invalid symbol.  ASX symbols must be alpha numeric maximum length 6 characters.';
### ASX.pm:  $info{ $symbol, 'errormsg' }
			next SYMBOL;
		}

		($status, $error) = asx_primary($symbol, $ua, \%info);

		if	(($status != 1) ||
			 ($info{$symbol, 'last'} eq '')) {
### ASX.pm  Calling Alternate URL as Primary URL failed or doesn't have a Last Price
			($status, $error) = asx_alternate($symbol, $ua, \%info);
		}

		if	($status != 1) {
			$info{ $symbol, 'success'  } = 0;
			$info{ $symbol, 'errormsg' } = "$error";
### ASX.pm  Unsuccessful calls to ASX URLs - symbol cannot be processed: $symbol
			next SYMBOL;
		}

### ASX.pm  We have valid data, apply various clean ups and add remaining data for symbol: $symbol

		# Remove trailing percentage sign from p_change
		$info{ $symbol, 'p_change' } =~ s/\%$//;

		$info{ $symbol, 'price' } = $info{ $symbol, 'last' };

		if	((exists $info{ $symbol, 'date' }) &&
			 ($info{ $symbol, 'date' } =~ m/([0-9]{4}-[0-9]{2}-[0-9]{2})T/)) {
			$quoter->store_date(\%info, $symbol, {isodate => $1});
### ASX.pm    Converted Last Trade Date to ISO format: "$info{ $symbol, 'date' } --> $1"
		}

# Technically indices don't have a currency, but it is not possible to distinguish them
		$info{ $symbol, 'currency' } = 'AUD';

		$info{ $symbol, 'success'  } = 1;
		$info{ $symbol, 'errormsg' } = '';

	}

### ASX.pm  Returning data for all symbols to Finance-Quote and exiting <file>[<line>]
	return %info if wantarray;
	return \%info;

}

# Internal function to handle ASX Alternate data source

sub asx_primary {

	my ($symbol, $ua, $info) = @_;

	my($data, $error, %label_map, $status, $url);

	$url = $ASX_URL_PRIMARY . $symbol;
	($status, $error, $data) = get_asx_data($url, $ua);
	return $status, $error unless $status == 1;

# Map the Finance::Quote labels (left) to the corresponding ASX labels (right)
	%label_map = (
		'bid'		=> 'bid_price',
		'p_change'	=> 'change_in_percent',
		'net'		=> 'change_price',
		'name'		=> 'desc_full',
		'high'		=> 'day_high_price',
		'low'		=> 'day_low_price',
		'eps'		=> 'eps',
		'last'		=> 'last_price',
		'date'		=> 'last_trade_date',
		'cap'		=> 'market_cap',
		'ask'		=> 'offer_price',
		'open'		=> 'open_price',
		'pe'		=> 'pe',
		'close'		=> 'previous_close_price',
		'volume'	=> 'volume',
	);

	process_asx_data($symbol, $data, \%label_map, $info);

	return 1, '';

}

# Internal function to handle ASX Alternate data source

sub asx_alternate {

	my ($symbol, $ua, $info) = @_;

	my($data, $error, %label_map, $status, $url);

	$url = $ASX_URL_ALTERNATE . $symbol . '/header';
	($status, $error, $data) = get_asx_data($url, $ua);
	return $status, $error unless $status == 1;

	if	(exists $data->{error}) {
		$status = 0;
		$error = "Error returned by ASX server '$url'.  Code: " . $data->{error}{code} . '  Message: ' . $data->{error}{message};
### ASX.pm  Error: $error
		return $status, $error;
	}

	if	(! exists $data->{data}) {
		$status = 0;
		$error = "Cannot parse content from ASX server '$url'.  Expected a top level JSON element named data.";
### ASX.pm  Error: $error
		return $status, $error;
	}

# Map the Finance::Quote labels (left) to the corresponding ASX labels (right)
	%label_map = (
		'name'		=> 'displayName',
		'ask'		=> 'priceAsk',
		'bid'		=> 'priceBid',
		'net'		=> 'priceChange',
		'p_change'	=> 'priceChangePercent',
		'last'		=> 'priceLast',
		'type'		=> 'securityType',
		'volume'	=> 'volume',
	);

	process_asx_data($symbol, $data->{data}, \%label_map, $info);

	return 1, '';

}

# Internal function to fetch, validate, and decode data from an ASX URL using LWP User Agent
# Handle any errors

sub get_asx_data {

	my ($url, $ua) = @_;

	my($data, $error, $json, $response, $status);

### ASX.pm  Retrieving data from ASX URL: $url
	$response = $ua->get($url);
	if	(! $response->is_success) {
		$status = 0;
		$error = "Unable to fetch data from the ASX server '$url'.  Status: " . $response->status_line;
### ASX.pm  Error: $error
		return $status, $error, undef;
	}

	if	($response->header('content-type') !~ m|application/json|i) {
		$status = 0;
		$error = "Invalid content-type from ASX server '$url'.  Expected: application/json, received: " . $response->header('content-type');
### ASX.pm  Error: $error
		return $status, $error, undef;
	}

	$json = $response->content;

# The JSON module will croak on errors, so use eval to trap this.
	$data = eval{ decode_json($json) };
	if	($@) {
		$status = 0;
		$error = "Failed to parse JSON data from ASX server '$url'.  Error: '$@'.";
### ASX.pm  Error: $error
		return $status, $error, undef;
	}

# Return valid, decoded data
	$status = 1;
	return $status, $error, $data;

}

# Internal function to push the ASX data elements into the Finance::Quote structure (%info)

sub process_asx_data {

	my ($symbol, $data, $label_map, $info) = @_;

	foreach my $label (sort(keys %{$label_map})) {
		if	((exists $data->{$label_map->{$label}}) &&
			 (defined $data->{$label_map->{$label}})) {
# Concatenate Primary and Alternate Names
			if	(($label eq 'name') &&
				 (exists $info->{$symbol, $label}) &&
				 (uc($info->{$symbol, $label}) ne uc($data->{$label_map->{$label}}))) {
					$info->{$symbol, $label} = $data->{$label_map->{$label}} . ' ' . $info->{$symbol, $label};
			}
# Overwrite all other labels
			else {
				$info->{$symbol, $label} = $data->{$label_map->{$label}};
			}
### ASX.pm    Mapped ASX data element to Finance-Quote: sprintf("%-22s%-15s%-s", $label_map->{$label}, $label, $data->{$label_map->{$label}})
		}
		else {
			$info->{$symbol,$label} = '';
		}
	}

	return;

}

1;
__END__

=head1 NAME
Finance::Quote::ASX - Obtain quotes from the Australian Stock Exchange.
=head1 SYNOPSIS
	use Finance::Quote;
	$q = Finance::Quote->new;
	%stockinfo = $q->fetch("asx","BHP");	   # Only query ASX.
	%stockinfo = $q->fetch("australia","BHP"); # Failover to other sources OK.
=head1 DESCRIPTION
This module obtains information from the Australian Stock Exchange
http://www.asx.com.au/.  Data for all Australian listed securities and indices
is available.  Indexes start with the letter 'X'.  For example, the
All Ordinaries is "XAO".  But some securities also start with the letter 'X'.
This module is loaded by default on a Finance::Quote object.  It's
also possible to load it explicitly by placing "ASX" in the argument
list to Finance::Quote->new().
This module provides both the "asx" and "australia" fetch methods.
Please use the "australia" fetch method if you wish to have failover
with other sources for Australian stocks (such as Yahoo).  Using
the "asx" method will guarantee that your information only comes
from the Australian Stock Exchange.
Information returned by this module is governed by the Australian
Stock Exchange's terms and conditions.
=head1 LABELS RETURNED
The following labels may be returned by Finance::Quote::ASX:
bid, offer, open, high, low, last, net, p_change, volume,
and price.
=head1 SEE ALSO
Australian Stock Exchange, http://www.asx.com.au/
Finance::Quote::Yahoo::Australia.
=cut
