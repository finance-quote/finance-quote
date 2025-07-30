#!/usr/bin/perl -w

#  SwissFundData.pm
#
#  Obtains quotes for CH Unit Trusts from https://swissfunddata.ch/ - please
#  refer to the end of this file for further information.
#
#  author: Manuel Friedli (manuel@fritteli.ch)
#
#  version: 0.1 Initial version - 27 July 2025
#
#  This file is heavily based on MStaruk.pm by Martin Sadler
#  (martinsadler@users.sourceforge.net), version 0.1, 01 April 2013
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
#    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
#    02110-1301, USA
#


package Finance::Quote::SwissFundData;
require 5.006;

use strict;
use warnings;

# URLs
use vars qw($VERSION $SFDCH_LOOK_UP $SFDCH_MAIN_URL);

use LWP::UserAgent;
use HTTP::Cookies;
use Web::Scraper;
use String::Util qw(trim);


$SFDCH_MAIN_URL	= "https://www.swissfunddata.ch";
$SFDCH_LOOK_UP	= "https://www.swissfunddata.ch/sfdpub/en/funds/prices?text=";

# VERSION

our $DISPLAY = "SwissFundData";
our @LABELS = qw/name currency date nav isodate method success errormsg/;
out $METHODHASH = {
	subroutine => \&swissfunddata,
	display => $DISPLAY,
	labels => \@LABELS
};

sub methodinfo {
	return (
		swissfunddata => $METHODHASH,
	);
}

sub labels {
	my %m = methodinfo();
	return map {$_ => [@{$m{$_}{labels}}]} keys %m;
}

sub methods {
	my %m = methodinfo();
	return map {$_ => $m{$_}{subroutine}} keys %m;
}

sub swissfunddata  {
    my $quoter = shift;
    my @symbols = @_;

    return unless @symbols;

    my %info;

    my $cookie_jar = HTTP::Cookies->new;
    $cookie_jar->set_cookie(0, "sfdpub-disclaimer", "private", "/sfdpub", "www.swissfunddata.ch", "443", 0, 0, 86400, 0);

    my $ua = $quoter->user_agent;
    $ua->cookie_jar($cookie_jar);

    foreach (@symbols) {
	my $symbol = $_;

	$info {$symbol, "source"} = "SwissFundData";
	$info {$symbol, "success"} = 1; # ever the optimist....
	$info {$symbol, "errormsg"} = "Success";

	# perform the look-up - if not found, return with error
	my $reply = $ua->get($SFDCH_LOOK_UP.$symbol);
	my $widget = scraper {
		process 'div#resultContainer table tbody tr:first-child td:nth-child(2)', 'name_isin' => ['HTML', sub {trim($_)}];
		process 'div#resultContainer table tbody tr:first-child td:nth-child(3)', 'nav_currency_date' => ['TEXT', sub {trim($_)}];
	};
	my $text = $widget->scrape($reply);
	
	unless (exists $text->{name_isin}) {
		# serious error, report it and give up
		$info {$symbol, "success"} = 0;
		$info {$symbol, "errormsg"} = "Error - failed to retrieve fund data: can not read name/isin.";
		next;	
	}

	unless (exists $text->{nav_currency_date}) {
		# serious error, report it and give up
		$info {$symbol, "success"} = 0;
		$info {$symbol, "errormsg"} = "Error - failed to retrieve basic fund data: can not read nav/currency/date";
		next;
	}

	my ($name, $isin);
	if ($text->{name_isin} =~ m[<a href=".+">(.*)</a>.*<br />(.*)]) {
		$name = trim($1);
		$isin = trim($2);
	}
	
	if (!defined($name)) {
		$name = "*** UNKNOWN ***";
	}
	if(!defined($isin)) {
		$isin = "*** UNKNOWN ***";
	}

	my ($nav, $currency, $date);
	if ($text->{nav_currency_date} =~ m[(\d+\.\d+) (\w+) (\d{2}\.\d{2}\.\d{4})]) {
		$nav = trim($1);
		$currency = trim($2);
		$date = trim($3);
	}

	if (!defined($nav)) {
		# serious error, report it and give up
		$info {$symbol, "success"} = 0;
		$info {$symbol, "errormsg"} = "Error - failed to retrieve fund data: missing 'nav'";
		next;
	}
	if (!defined($currency)) {
		# serious error, report it and give up
		$info {$symbol, "success"} = 0;
		$info {$symbol, "errormsg"} = "Error - failed to retrieve fund data: missing 'currency'";
		next;
	}
	if (!defined($date)) {
		# serious error, report it and give up
		$info {$symbol, "success"} = 0;
		$info {$symbol, "errormsg"} = "Error - failed to retrieve fund data: missing 'date'";
		next;
	}
	
	$info {$symbol, "name"} = $name;
	$info {$symbol, "isin"} = $isin;
	$info {$symbol, "nav"} = $nav;
	$info {$symbol, "currency"} = $currency;
	$quoter->store_date(\%info, $symbol, {eurodate => $date);
	$info {$symbol, "method"} = "swissfunddata";
	# It seems that GnuCash insists on having the time set?!
	$info {$symbol, "time"} = "12:00";
    }

    return wantarray ? %info : \%info;
}

1;

=head1 NAME

Finance::Quote::SwissFindData - Obtain CH Unit Trust quotes from swissfunddata.ch.

=head1 SYNOPSIS

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("swissfunddata","<isin> ...");  # Only query swissfunddata.ch using ISINs

=head1 DESCRIPTION

This module fetches information from the SwissFindData Funds service,
https://swissfunddata.ch/.

Funds are identified by their ISIN code.

This module is loaded by default on a Finance::Quote object. It's
also possible to load it explicitly by placing "swissfunddata" in the argument
list to Finance::Quote->new().

Information obtained by this module may be covered by SwissFundData
terms and conditions. See https://swissfunddata.ch/ for details.

=head2 Stocks And Indices

This module provides the "swissfunddata" fetch method for fetching CH Unit
Trusts and OEICs prices and other information from swissfunddata.ch.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::swissfunddata :

    name, isin, nav, currency, date, isodate, method, success, errormsg.


=head1 SEE ALSO

SwissFundData websites, https://www.swissfunddata.ch


=head1 AUTHOR

Manuel Friedli, E<lt>manuel@fritteli.chE<gt>
Based heavily on the work of Martin Sadler E<lt>martinsadler@users.sourceforge.netE<gt>, many thanks!

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2025 by Manuel Friedli

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.


=cut

__END__
