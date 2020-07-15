#!/usr/bin/perl -w

#  ftfunds.pm
#
#  Obtains quotes for UK Unit Trusts from http://funds.ft.com/ - please
#  refer to the end of this file for further information.
#
#  author: Martin Sadler (martinsadler@users.sourceforge.net)
#
#  Version 0.1 Initial version - 06 Sep 2010
#
#  Version 0.2 Better look-up  - 19 Sep 2010
#
#  Version 0.3 name changed to "ftfunds"
#              (all lower case) and tidy-up - 31 Jan 2011
#
#  Version 0.4 Allows alphanumerics MEXIDs
#              and back to "FTfunds"        - 28 Feb 2011
#
#  Version 1.0 Changed to work with the new
#              format of funds.ft.com       - 14 Sep 2011
#
#  Version 2.0 Changed to work with the latest
#              format of funds.ft.com		- 31 Mar 2013
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


package Finance::Quote::FTfunds;
require 5.005;

use strict;
use warnings;

# Set DEBUG => 0 for no debug messages, => 1 for first level, => 2 for 2nd level, etc.

use constant DEBUG => 0;

# URLs
use vars qw($VERSION $FTFUNDS_LOOK_UD $FTFUNDS_LOOK_LD $FTFUNDS_MAIN_URL);

use LWP::UserAgent;
use HTTP::Request::Common;
use HTTP::Cookies;
use HTML::TokeParser;
# use Data::Dumper;

# VERSION

$FTFUNDS_MAIN_URL   =   "https://markets.ft.com";
$FTFUNDS_LOOK_LD    =   "https://markets.ft.com/data/funds/tearsheet/summary?s=";
$FTFUNDS_LOOK_UD    =	"http://funds.ft.com/UnlistedTearsheet/Summary?s=";

                        # this will work with ISIN codes only.

# FIXME -

sub methods { return (ftfunds => \&ftfunds_fund,
		      ukfunds => \&ftfunds_fund); }

{
    my @labels = qw/name currency last date time price nav source iso_date method net p_change success errormsg/;

    sub labels { return (ftfunds => \@labels,
			 ukfunds => \@labels); }
}

#
# =======================================================================

sub ftfunds_fund  {
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
		elsif ($code =~ m/^[a-zA-Z0-9]{4,6}(.*)/ && !$1)         { $code_type = "MEXID"; }

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

# try listed funds first...

		my $webdoc  = $ua->get($FTFUNDS_LOOK_LD.$code);
    	if (!$webdoc->is_success)
		{
	        # serious error, report it and give up
			$fundquote {$code,"success"} = 0;
			$fundquote {$code,"errormsg"} =
		       		"Error - failed to retrieve fund data : HTTP status = ".$webdoc->status_line;
			next;
		}

DEBUG and print "\nTitle  = ",$webdoc->title,"\n";
DEBUG and print "\nStatus = ",$webdoc->status_line, "\n";
DEBUG > 1 and print "\nCookie Jar = : \n",Dumper($cj),"\n\n";

		$fundquote {$code, "source"} = $FTFUNDS_LOOK_LD.$code;

# if page contains "<h2>0 results</h2>" it's not found...
# ... try unlisted funds...

		if ($webdoc->content =~
        m[<h2>(0 results)</h2>] )
    	{
DEBUG and print "\nTrying unlisted funds for ",$code," : ",$1,"\n";
			$webdoc  = $ua->get($FTFUNDS_LOOK_UD.$code);
			if (!$webdoc->is_success)
        	{
	        	# serious error, report it and give up
				$fundquote {$code,"success"} = 0;
				$fundquote {$code,"errormsg"} =
		        		"Error - failed to retrieve fund data : HTTP status = ".$webdoc->status_line;
				next;
			}

DEBUG and print "\nTitle  = ",$webdoc->title,"\n";
DEBUG and print "\nStatus = ",$webdoc->status_line, "\n";
DEBUG > 1 and print "\nCookie Jar = : \n",Dumper($cj),"\n\n";

			$fundquote {$code, "source"} = $FTFUNDS_LOOK_UD.$code;
		}

		$fundquote {$code, "symbol"} = $code;

# Find name by simple regexp

        my $name;
		if ($webdoc->content =~
        m[<title>(.*) [Ss]ummary - FT.com] )
        {
            $name = $1 ;
        }
		if (!defined($name)) {
			# not a serious error - don't report it ....
			# ... but set a useful message ....
			$fundquote {$code,"errormsg"} = "Warning - failed to find fund name";
			$name = "*** UNKNOWN ***";
			# ... and continue
		}
		$fundquote {$code, "name"} = $name;	# set name

# Find price and currency
		my $currency;
		my $price;
		if ($webdoc->content =~
		m[<span class="mod-ui-data-list__label">Price [(]([A-Z]{3})[)]</span><span class="mod-ui-data-list__value">([\.\,0-9]*)</span>]  )
        {
			$currency = $1;
			$price    = $2;
        }
		if (!defined($currency)) {
			# serious error, report it and give up
			$fundquote {$code,"success"} = 0;
			$fundquote {$code,"errormsg"} = "Error - failed to find a currency";
			next;
		}
		if (!defined($price)) {
			# serious error, report it and give up
			$fundquote {$code,"success"} = 0;
			$fundquote {$code,"errormsg"} = "Error - failed to find a price";
			next;
		}
		if ($price =~ m[([0-9]*),([\.0-9]*)])
		{
				$price	  = $1 * 1000 + $2;
		}

# Find net and percent-age change
		my $net;
		my $pchange;
		if ($webdoc->content =~
		m[<span class="mod-ui-data-list__label">Today's Change</span><span class="mod-ui-data-list__value"><span [^>]*><i [^>]*></i>(-?[\.0-9]*) / (-?[\.0-9]*)%</span>] )
        {
            $net = $1 ;
            $pchange = $2;
        }
		if (!defined($net)) {
			# not a serious error - don't report it ....
#			$fundquote {$code,"success"} = 0;
			# ... but set a useful message ....
			$fundquote {$code,"errormsg"} = "Warning - failed to find a net change.";
			$net = "-0.00";					# ???? is this OK ????
			# ... and continue
		}
		if (!defined($pchange)) {
			# not a serious error - don't report it ....
#			$fundquote {$code,"success"} = 0;
			# ... but set a useful message ....
			$fundquote {$code,"errormsg"} = "Warning - failed to find a %-change";
			$pchange = "-0.00";					# ???? is this OK ????
			# ... and continue
		}
		if ($net =~ m[([0-9]*),([\.0-9]*)])
		{
			$net	  = $1 * 1000 + $2;
		}
		if ($pchange =~ m[([0-9]*),([\.0-9]*)])
		{
			$pchange	  = $1 * 1000 + $2;
		}

# deal with GBX pricing of UK unit trusts
		if ($currency eq "GBX")
		{
			$currency = "GBP" ;
			$price = $price / 100 ;
            $net   = $net   / 100 ;
		}

	# now set prices, net change and currency

		$fundquote {$code, "price"} = $price;
		$fundquote {$code, "last"} = $price;
		$fundquote {$code, "nav"} = $price;
        $fundquote {$code, "net"} = $net;
		$fundquote {$code, "currency"} = $currency;
		$fundquote {$code, "p_change"} = $pchange;	# set %-change

# Find time

# NB. version 2.0 - there is no time quoted on the current (31/3/2013) factsheet page for unit trusts
# ... this code left in in case it is available in later revisions of the page

		my $time;
		if ($webdoc->content =~ m[......... some string that will identify the time ............] )
        {
            if ($1 =~ m[(\d\d:\d\d)] )  # strip any trailing text (Timezone, etc.)
            {
                $time = $1;
            }
        }
		if (!defined($time)) {
			# not a serious error - don't report it ....
#			$fundquote {$code,"success"} = 0;
			# ... but set a useful message ....
			$fundquote {$code,"errormsg"} = "Warning - failed to find a time";
			$time = "17:00";	# set to 17:00 if no time supplied ???
                               	# gnucash insists on having a valid-format
			# ... and continue
		}

		$fundquote {$code, "time"} = $time; # set time

# Find date

		my $date;
		if ($webdoc->content =~
		m[([A-Za-z]{3}) ([0-9]{2}) ([0-9]{4})] )
        {
        	$date = "$2/$1/$3" ;
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
			$quoter->store_date(\%fundquote, $code, {eurodate => $date});
		}

		$fundquote {$code, "method"} = "ftfunds";   # set method
		sleep 1;									# go to sleep for a while to give the web-site a breather

    }	# end of "foreach (@symbols)"

	return wantarray ? %fundquote : \%fundquote;
}

1;

=head1 NAME

Finance::Quote::FTfunds - Obtain UK Unit Trust quotes from FT.com (Financial Times).

=head1 SYNOPSIS

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("ftfunds","<isin> ...");  # Only query FT.com using ISINs

=head1 DESCRIPTION

This module fetches information from the Financial Times Funds service,
http://funds.ft.com. There are over 47,000 UK Unit Trusts and OEICs quoted,
as well as many Offshore Funds and Exhange Traded Funds (ETFs). It converts
any funds quoted in GBX (pence) to GBP, dividing the price by 100 in the
process.

Funds are identified by their ISIN code, a 12 character alphanumeric code.
Although the web site also allows searching by fund name, this version of
Finance::Quote::FTfunds only implements ISIN lookup. To determine the ISIN for
funds of interest to you, visit the funds.ft.com site and use the flexible search
facilities to identify the funds of interest. The factsheet display for any given
fund displays the ISIN along with other useful information.

This module is loaded by default on a Finance::Quote object. It's
also possible to load it explicitly by placing "ftfunds" in the argument
list to Finance::Quote->new().

Information obtained by this module may be covered by funds.ft.com
terms and conditions See http://funds.ft.com/ and http://ft.com for details.

=head2 Stocks And Indices

This module provides both the "ftfunds" and "ukfunds" fetch methods for
fetching UK and Offshore Unit Trusts and OEICs prices and other information
from funds.ft.com. Please use the "ukfunds" fetch method if you wish to have
failover with future sources for UK and Offshore Unit Trusts and OEICs - the
author has plans to develop Finance::Quote modules for the London Stock Exchange
and Morningstar unit trust services. Using the "ftfunds" method will guarantee
that your information only comes from the funds.ft.com website.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::ftfunds :

    name, currency, last, date, time, price, nav, source, method,
    iso_date, net, p_change, success, errormsg.


=head1 SEE ALSO

Financial Times websites, http://ft.com and http://funds.ft.com


=head1 AUTHOR

Martin Sadler, E<lt>martinsadler@users.sourceforge.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Martin Sadler

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.


=cut

__END__
