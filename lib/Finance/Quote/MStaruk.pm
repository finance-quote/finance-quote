#!/usr/bin/perl -w

#  MStaruk.pm
#
#  Obtains quotes for UK Unit Trusts from http://morningstar.co.uk/ - please
#  refer to the end of this file for further information.
#
#  author: Martin Sadler (martinsadler@users.sourceforge.net)
#
#  version: 0.1 Initial version - 01 April 2013
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


package Finance::Quote::MStaruk;
require 5.005;

use strict;
use warnings;

# URLs
use vars qw($VERSION $MSTARUK_NEXT_URL $MSTARUK_LOOK_UP $MSTARUK_MAIN_URL);

use LWP::Simple;
use LWP::UserAgent;
use HTTP::Request::Common;
use HTTP::Cookies;

# VERSION

$MSTARUK_MAIN_URL   =   "http://www.morningstar.co.uk";
$MSTARUK_LOOK_UP    =   "http://www.morningstar.co.uk/uk/funds/SecuritySearchResults.aspx?search=";
$MSTARUK_NEXT_URL	=	"http://www.morningstar.co.uk/uk/funds/snapshot/snapshot.aspx?id=";

# FIXME -

sub methods { return (mstaruk => \&mstaruk_fund,
		      			ukfunds => \&mstaruk_fund); }

{
    my @labels = qw/name currency last date time price nav source iso_date method net p_change success errormsg/;

    sub labels { return (mstaruk => \@labels,
			 				ukfunds => \@labels); }
}

#
# =======================================================================

sub mstaruk_fund  {
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

        my $webdoc  = get($MSTARUK_LOOK_UP.$code);
        if (!$webdoc)
        {
	        # serious error, report it and give up
		    $fundquote {$code,"success"} = 0;
		    $fundquote {$code,"errormsg"} =
		        "Error - failed to retrieve fund data";
		    next;
	    }
	    $fundquote {$code, "symbol"} = $code;
	    $fundquote {$code, "source"} = $MSTARUK_MAIN_URL;

# Find name by regexp

        my ($name, $nexturl, $isin);
 		if ($webdoc =~
        m[<td class="msDataText searchLink"><a href="(.*?)">(.*?)</a></td><td class="msDataText searchIsin"><span>[a-zA-Z]{2}[a-zA-Z0-9]{9}\d(.*)</span></td>] )
        {
            $nexturl = $1;
            $name = $2;
            $isin = $3;
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

# modify $nexturl to remove html escape encoding for the Ampersand (&) character

		$nexturl =~ s/&amp;/&/;

# Now need to look-up next page using $next_url

        $webdoc  = get($MSTARUK_MAIN_URL.$nexturl);
        if (!$webdoc)
        {
	        # serious error, report it and give up
		    $fundquote {$code,"success"} = 0;
		    $fundquote {$code,"errormsg"} =
		        "Error - failed to retrieve fund data";
		    next;
	    }

# Find date, currency and price all in one table row

		my ($currency, $date, $price, $pchange);
		if ($webdoc =~
		m[<td class="line heading">NAV<span class="heading"><br />([0-9]{2}/[0-9]{2}/[0-9]{4})</span>.*([A-Z]{3}).([0-9\.]+).*>([0-9\.\-]+)] )
        {

            $date = $1;
            $currency = $2;
            $price = $3;
            $pchange = $4;
        }

		if (!defined($pchange)) {
			# not a serious error - don't report it ....
#			$fundquote {$code,"success"} = 0;
			# ... but set a useful message ....
			$fundquote {$code,"errormsg"} = "Warning - failed to find net or %-age change";
			# set to (minus)zero
            $pchange = -0.00;
			# ... and continue
		}
		$fundquote {$code, "p_change"} = $pchange;	# set %-change

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
		    $quoter->store_date(\%fundquote, $code, {eurodate => $date});
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

# Calculate net change - it's not included in the morningstar factsheets

		my $net = ($price * $pchange) / 100 ;

# deal with GBX pricing of UK unit trusts

		if ($currency eq "GBX")
		{
			$currency = "GBP" ;
			$price = $price / 100 ;
            $net   = $net   / 100 ;
		}

		# now set prices and currency

		$fundquote {$code, "price"} = $price;
		$fundquote {$code, "last"} = $price;
		$fundquote {$code, "nav"} = $price;
		$fundquote {$code, "net"} = $net;
		$fundquote {$code, "currency"} = $currency;

# Set a dummy time as gnucash insists on having a valid format

		my $time = "12:00";     # set to Midday if no time supplied ???
                                # gnucash insists on having a valid-format

		$fundquote {$code, "time"} = $time; # set time

		$fundquote {$code, "method"} = "mstaruk";   # set method

	}

	return wantarray ? %fundquote : \%fundquote;
}

1;

=head1 NAME

Finance::Quote::mstaruk - Obtain UK Unit Trust quotes from morningstar.co.uk.

=head1 SYNOPSIS

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("mstaruk","<isin> ...");  # Only query morningstar.co.uk using ISINs
    %info = Finance::Quote->fetch("ukfunds","<isin> ...");  # Failover to other sources

=head1 DESCRIPTION

This module fetches information from the MorningStar Funds service,
http://morningstar.com/uk/. There are many UK Unit Trusts and OEICs quoted,
as well as many Offshore Funds and Exhange Traded Funds (ETFs). It converts
any funds quoted in GBX (pence) to GBP, dividing the price by 100 in the
process.

Funds are identified by their ISIN code.

This module is loaded by default on a Finance::Quote object. It's
also possible to load it explicitly by placing "mstaruk" in the argument
list to Finance::Quote->new().

Information obtained by this module may be covered by funds.ft.com
terms and conditions See http://morningstar.co.ukfor details.

=head2 Stocks And Indices

This module provides both the "mstaruk" and "ukfunds" fetch methods for
fetching UK and Offshore Unit Trusts and OEICs prices and other information
from funds.ft.com. Please use the "ukfunds" fetch method if you wish to have
failover with future sources for UK and Offshore Unit Trusts and OEICs - the
author has plans to develop Finance::Quote modules for other source providing
unit trust prices. Using the "mstaruk" method will guarantee
that your information only comes from the morningstar.co.uk website.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::mstaruk :

    name, currency, last, date, time, price, nav, source, method,
    iso_date, net, p_change, success, errormsg.


=head1 SEE ALSO

Morning Star websites, http://morningstar.co.uk


=head1 AUTHOR

Martin Sadler, E<lt>martinsadler@users.sourceforge.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Martin Sadler

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.


=cut

__END__
