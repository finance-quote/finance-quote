#!/usr/bin/perl -w
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#    Copyright (C) 2001, Leigh Wedding <leigh.wedding@telstra.com>
#    Copyright (C) 2000-2004, Paul Fenwick <pjf@cpan.org>
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

package Finance::Quote::HSBCBrasil;

use HTTP::Request::Common;
use LWP::UserAgent;
use HTML::TableExtract;


use vars qw/$HSBCBrasil_URL $VERSION/;

$VERSION = "1.05";

$HSBCBrasil_URL = 'http://www.hsbc.com.br/wcm/premier/fundos/rentfundos_gr.shtml';

sub methods {return (hsbcbrasil => \&hsbcbrasil)}

{
	my @labels = qw/name date last p_change 
	                price method exchange currency/;

	sub labels { return (hsbcbrasil => \@labels); }
}


# Convert number separators to US values
sub convert_price {
	$_ = shift;
	s/\.//g;
	s/,/\./g;
	return $_;
}

# Trim leading and tailing whitespaces (also non-breakable whitespaces)
# remove the |N| symbol
sub trim {
    $_ = shift;
    s/\|N\|//;
    s/^\s*//;
    s/\s*$//;
    s/&nbsp;//g;
    return $_;
}

# Get the month of the quote
sub q_month {
	$_=shift();
	s/^...//;
	return $_;
}


sub hsbcbrasil {
	my $quoter = shift;
	my @stocks = @_;
	return unless @stocks;
	my %info;

	my ($Second, $Minute, $Hour, $Day, $Month, $Year, $WeekDay, $DayOfYear, $IsDST) = localtime(time);
	$Year += 1900;
	$Month++;

	my $ua = $quoter->user_agent;

	my $response = $ua->request(GET $HSBCBrasil_URL);
	unless ($response->is_success) {
		foreach my $stock (@stocks) {
			$info{$stock,"success"} = 0;
			$info{$stock,"errormsg"} = "HTTP session failed";
		}
		return wantarray() ? %info : \%info;
	}

	my $te = HTML::TableExtract->new(depth => 2, count => 1);

	$te->parse($response->content);

	# Extract table contents.
	my @rows;
	foreach my $ts ($te->tables) {
        	foreach my $row ($ts->rows) {
			foreach my $stock (@stocks) {	
				next unless $$row[0]; #remove emptly cell for fetching		
				next unless (trim($stock) eq trim($$row[0]));
				$info{$stock,'symbol'} = $stock;
				$info{$stock,"name"} = $stock;
				$info{$stock,"p_change"} = convert_price(@$row[3]);
				if ((q_month(@$row[1]) eq "12") && ($Month eq "1")) {
					$Year--;
				}
				$quoter->store_date(\%info, $stock, {eurodate => "@$row[1]/$Year"});
        	        	$info{$stock,"last"} = convert_price(@$row[2]);

				# Currencies

				$info{$stock, "currency"} = "BRL";

				$info{$stock, "method"} = "hsbcbrasil";
				$info{$stock, "exchange"} = "HSBC Brasil";
				$info{$stock, "price"} = $info{$stock,"last"};
				$info{$stock, "success"} = 1;
			}
        	}
	}

	# return error message for funds not found
	foreach my $stock (@stocks) {
	next if defined $info{$stock,'symbol'};
	$info{$stock,"success"} = 0;
	$info{$stock,"errormsg"} = "Fund not found in www.hsbc.com.br";			
	}


	# All done.

	return %info if wantarray;
	return \%info;
}

1;

=head1 NAME

Finance::Quote::HSBCBrasil	- Obtain quotes for the funds of bank HSBC Brasil

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %stockinfo = $q->fetch("hsbcbrasil","HSBC FIA VALOR");	   # Query hsbcbrasil for fund named HSBC FIA VALOR

=head1 DESCRIPTION

This module obtains information from the bank HSBC Brasil
http://www.hsbc.com.br/.  Only funds from last traded session
are available. HSBC Brasil doesn't have symbol for their funds,
so write the full name as symbol.

Information returned by this module is HSBC Brasil terms and conditions.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::HSBCBrasil:
date, last, p_change, volume, currency and price.

=head1 SEE ALSO

Lists of funds from HSBC Brasil:
http://www.hsbc.com.br/wcm/premier/fundos/rentfundos_gr.shtml

=cut

 	  	 
