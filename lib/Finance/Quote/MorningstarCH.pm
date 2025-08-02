#!/usr/bin/perl -w
# vi: set ts=4 sw=4 noai ic showmode showmatch: 

#  MorningstarCH.pm
#
#  Obtains quotes for CH Unit Trusts from http://morningstar.ch/ - please
#  refer to the end of this file for further information.
#
#  author: Manuel Friedli (manuel@fritteli.ch)
#
#  version: 0.2 Updated version - 30 July 2025
#
#  This file is heavily based on MorningstarUK.pm by Martin Sadler
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


package Finance::Quote::MorningstarCH;

use strict;
use warnings;

# URLs
use vars qw($VERSION $MSTARCH_NEXT_URL $MSTARCH_LOOK_UP $MSTARCH_MAIN_URL);

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use LWP::Simple;
use LWP::UserAgent;
use HTTP::Request::Common;
use HTTP::Cookies;
use JSON qw(decode_json);
use Text::Template;

# VERSION

$MSTARCH_MAIN_URL   =   "https://www.morningstar.ch";
$MSTARCH_LOOK_UP    =   "https://www.morningstar.ch/ch/funds/SecuritySearchResults.aspx?search=";
$MSTARCH_NEXT_URL = Text::Template->new( TYPE => 'STRING', SOURCE => 'https://api-global.morningstar.com/sal-service/v1/fund/quote/v7/{$secid}/data?fundServCode=&showAnalystRatingChinaFund=false&showAnalystRating=false&hideesg=false&region=EEA&languageId=en-eu&locale=en-eu&clientId=MDC&benchmarkId=mstarorcat&component=sal-mip-investment-overview&version=4.65.0' );

# FIXME - Needs cleanup

our $DISPLAY    = 'Morningstar CH';
our @LABELS = qw/name currency last date price nav source iso_date method success errormsg/;
our $METHODHASH = {subroutine => \&mstarch_fund,
                   display => $DISPLAY,
                   labels => \@LABELS};

sub methodinfo {
    return (
        morningstarch => $METHODHASH,
        mstarch       => $METHODHASH,
    );
}

sub methods {
	my %m = methodinfo();
	return map {$_ => $m{$_}{subroutine} } keys %m;
}

sub labels {
	my %m = methodinfo();
	return map {$_ => [@{$m{$_}{labels}}] } keys %m;
}

#
# =======================================================================

sub mstarch_fund  {
    my $quoter = shift;
    my @symbols = @_;

    return unless @symbols;

    my %fundquote;

    my $ua = $quoter->user_agent;
    my $cj = HTTP::Cookies->new();
    $ua->cookie_jar( $cj );

    foreach (@symbols)
    {
	    my $code = $_;

	    my $code_type = "** Invalid **";
	    if ($code =~ m/^[a-zA-Z]{2}[a-zA-Z0-9]{9}\d(.*)/ && !$1) { $code_type = "ISIN";  }
	    elsif ($code =~ m/^[a-zA-Z0-9]{6}\d(.*)/ && !$1 )        { $code_type = "SEDOL"; }
	    elsif ($code =~ m/^[a-zA-Z]{4,6}(.*)/ && !$1)            { $code_type = "MEXID"; }

# current version can only use ISIN - report an error and exit if any other type

        if ($code_type ne "ISIN")
        {
		    $fundquote {$code,"success"} = 0;
		    $fundquote {$code,"errormsg"} = "Error - invalid symbol";
		    next;
        }

	    $fundquote {$code,"success"} = 1; # ever the optimist....
	    $fundquote {$code,"errormsg"} = "Success";

# perform the look-up - if not found, return with error

        my $webdoc  = get($MSTARCH_LOOK_UP.$code);
        if (!$webdoc)
        {
	        # serious error, report it and give up
		    $fundquote {$code,"success"} = 0;
		    $fundquote {$code,"errormsg"} =
		        "Error - failed to retrieve fund data";
		    next;
	    }

		### [<now>] webdoc: $webdoc

	    $fundquote {$code, "symbol"} = $code;
	    $fundquote {$code, "source"} = $MSTARCH_MAIN_URL;

# Find name by regexp

        my ($name, $nexturl, $secid);
 		if ($webdoc =~
        m[<td class="msDataText searchLink"><a href="(.*?id=([A-Z0-9]+))">(.*?)</a></td><td class="msDataText searchIsin"><span>[a-zA-Z]{2}[a-zA-Z0-9]{9}\d(.*)</span></td>] )
        {
            $nexturl = $1;
            $secid = $2;
			### [<now>] secID: $secid
            $name = $3;
        }

		if (!defined($name)) {
			# not a serious error - don't report it ....
#			$fundquote {$code,"success"} = 0;
			# ... but set a useful message ....
			$fundquote {$code,"errormsg"} = "Warning - failed to find fund name";
			$name = "*** UNKNOWN ***";
			# ... and continue
		}
		$fundquote {$code, "name"} = $name;	# set name

		if (!defined($nexturl)) {
	        # serious error, report it and give up
		    $fundquote {$code,"success"} = 0;
		    $fundquote {$code,"errormsg"} =
		        "Error - failed to retrieve fund data";
		    next;
		}

		$nexturl = $MSTARCH_NEXT_URL->fill_in(HASH => {secid => $secid});
		$ua->default_header('Apikey' => 'lstzFDEOhfFNMLikKa0am9mgEKLBl49T');

		### [<now>] NextURL: $nexturl

		my $response = $ua->request( GET $nexturl );

		if ($response->code != 200 ) {
			$fundquote {$code,"success"} = 0;
			$fundquote {$code,"errormsg"} = "Error - $code not found";
			next;
		}

		$webdoc = $response->content;
		### [<now>] 2nd Webdoc: $webdoc

		my $json;
		eval {$json = decode_json $webdoc};
        if ($@) {
	        # serious error, report it and give up
		    $fundquote {$code,"success"} = 0;
		    $fundquote {$code,"errormsg"} =
		        "Error - failed to retrieve fund data - could not decode JSON";
		    next;
	    }
		### [<now>] JSON: $json

# Find date, currency and price all in one table row

		my ($date, $time);
		my $currency = $json->{'currency'};
		my $price    = $json->{'nav'};
		if ( $json->{'latestPriceDate'} =~ m|(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2}):| ) {
			$date = $1;
			$time = $2;
		}

		if (!defined($date)) {
			# not a serious error - don't report it ....
#			$fundquote {$code,"success"} = 0;
			# ... but set a useful message ....
			$fundquote {$code,"errormsg"} = "Warning - failed to find a date";
			# use today's date
            $quoter->store_date(\%fundquote, $code, {today => 1});
			# ... and continue
		}
		else
		{
		    $quoter->store_date(\%fundquote, $code, {isodate => $date});
		}

		if (!defined($price)) {
	    	# serious error, report it and give up
			$fundquote {$code,"success"} = 0;
			$fundquote {$code,"errormsg"} = "Error - failed to find a price";
			next;
		}

		if (!defined($currency)) {
	    	# serious error, report it and give up
			$fundquote {$code,"success"} = 0;
			$fundquote {$code,"errormsg"} = "Error - failed to find a currency";
			next;
		}

		# defer setting currency and price until we've dealt with possible GBX currency...

# deal with GBX pricing of UK unit trusts

		if ($currency eq "GBX")
		{
			$currency = "GBP" ;
			$price = $price / 100 ;
		}

		# now set prices and currency

		$fundquote {$code, "price"} = $price;
		$fundquote {$code, "last"} = $price;
		$fundquote {$code, "nav"} = $price;
		$fundquote {$code, "currency"} = $currency;

		$fundquote {$code, "method"} = "morningstaruk";   # set method

	}

	return wantarray ? %fundquote : \%fundquote;
}

1;

=head1 NAME

Finance::Quote::MorningstarCH - Obtain CH Unit Trust quotes from morningstar.ch.

=head1 SYNOPSIS

    $q = Finance::Quote->new;

    %info = $q->fetch("morningstarch","<isin> ...");  # Only query morningstar.ch using ISINs

=head1 DESCRIPTION

This module fetches information from the MorningStar Funds service,
https://morningstar.com/ch/.

Funds are identified by their ISIN code.

This module is loaded by default on a Finance::Quote object. It's
also possible to load it explicitly by placing "morningstarch" in the argument
list to Finance::Quote->new().

Information obtained by this module may be covered by Morningstar
terms and conditions See https://morningstar.ch/ for details.

=head2 Stocks And Indices

This module provides the "morningstarch" fetch method for fetching CH Unit
Trusts and OEICs prices and other information from morningstar.ch.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::MorningstarCH :

    name, currency, last, date, time, price, nav, source, method,
    iso_date, net, p_change, success, errormsg.


=head1 SEE ALSO

Morning Star websites, https://morningstar.ch


=head1 AUTHOR

Manuel Friedli, E<lt>manuel@fritteli.chE<gt>
Based heavily on the work of Martin Sadler, E<lt>martinsadler@users.sourceforge.netE<gt>, many thanks!

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2019, 2025 by Manuel Friedli

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.


=cut

__END__
