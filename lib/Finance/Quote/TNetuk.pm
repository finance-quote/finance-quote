#!/usr/bin/perl -w

#  TNetuk.pm
#
#  Obtains quotes for UK Unit Trusts from http://trustnet.com/ - please
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
#    Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
#    02111-1307, USA
#


package Finance::Quote::TNetuk;
require 5.005;

use strict;
use warnings;

# Set DEBUG => 0 for no debug messages, => 1 for first level, => 2 for 2nd level, etc.

use constant DEBUG => 0;

# URLs
use vars qw($VERSION $TNETUK_NEXT_URL $TNETUK_LOOK_UP $TNETUK_MAIN_URL);

use LWP::Simple;
use LWP::UserAgent;
use HTTP::Request::Common;
use HTTP::Cookies;
use HTML::TokeParser;
# use Data::Dumper;

# VERSION

$TNETUK_MAIN_URL   =   "http://www.trustnet.com";
$TNETUK_LOOK_UP    =   "http://www.trustnet.com/Tools/Search.aspx?keyword=";
$TNETUK_NEXT_URL	=	"/Factsheets/Factsheet.aspx?fundcode=";

# FIXME -

sub methods { return (tnetuk => \&tnetuk_fund,
		      			ukfunds => \&tnetuk_fund); }

{
    my @labels = qw/name currency last date time price nav source iso_date method net p_change success errormsg/;

    sub labels { return (tnetuk => \@labels,
			 				ukfunds => \@labels); }
}

#
# =======================================================================

sub tnetuk_fund  {
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

        my $webdoc  = $ua->get($TNETUK_LOOK_UP.$code);
        if (!$webdoc->is_success)
        {
	        # serious error, report it and give up
		    $fundquote {$code,"success"} = 0;
		    $fundquote {$code,"errormsg"} =
		        "Error - failed to retrieve fund data : HTTP Status = ",$webdoc->status_line;
		    next;
	    }
	    $fundquote {$code, "symbol"} = $code;
	    $fundquote {$code, "source"} = $TNETUK_MAIN_URL;

DEBUG and print "\nTitle  = ",$webdoc->title,"\n";
DEBUG and print "\nStatus = ",$webdoc->status_line, "\n";
#DEBUG > 1 and print "\nCookie Jar = : \n",Dumper($cj),"\n\n";
DEBUG > 1 and my $outfile = "tnetuk-p1-".$code.".txt";
DEBUG > 1 and open (OUT,">$outfile");
DEBUG > 1 and print OUT $webdoc->content;
DEBUG > 1 and close(OUT);

# Find name and next url using TokeParser

		my $htmlstream	=	HTML::TokeParser->new(\$webdoc->content);

		my $done = 0;
        my ($tag, $name, $nexturl, $univ);
		while ( ( $tag = $htmlstream->get_tag('a')) && !$nexturl )
		{
			if ( $tag->[1]{'href'} )
			{
DEBUG and print "\nTag-item 'href' = ",$tag->[1]{'href'},"\n";
				if ( $tag->[1]{'href'} =~ m[^/Factsheets/Factsheet\.aspx.*univ=(.).*] )
				{
					$univ = $1;
DEBUG and print "\nUniv = ",$univ,"\n";
					$nexturl = $tag->[1]{'href'};
					$name    = $htmlstream->get_trimmed_text('/a');
				}
			}
		}

DEBUG and print "\nNext URL = ",$nexturl,"\n";
DEBUG and print "\bName     = ",$name,"\n";

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
		    $fundquote {$code,"errormsg"} = "Error - failed to retrieve fund data";
		    next;
		}

# need SEDOL to identify the correct line in the next web-page

        my $sedol;
        if ($code =~ m[^[a-zA-Z]{2}[0-9]{2}([a-zA-Z0-9]{7})\d])
        {
        	$sedol = $1;
        }
DEBUG and print "SEDOL for ",$code," = ",$sedol,"\n";

# modify $nexturl to remove html escape encoding for the Ampersand (&) character

		$nexturl =~ s/&amp;/&/;

# Now need to look-up next page using $next_url

        $webdoc  = $ua->get($TNETUK_MAIN_URL.$nexturl);
        if (!$webdoc->is_success)
        {
	        # serious error, report it and give up
		    $fundquote {$code,"success"} = 0;
		    $fundquote {$code,"errormsg"} =
		        "Error - failed to retrieve fund data : HTTP Status = ",$webdoc->status_line;
		    next;
	    }

DEBUG and print "\nTitle  = ",$webdoc->title,"\n";
DEBUG and print "\nStatus = ",$webdoc->status_line, "\n";
#DEBUG > 1 and print "\nCookie Jar = : \n",Dumper($cj),"\n\n";
DEBUG > 1 and $outfile = "tnetuk-p2-".$code.".txt";
DEBUG > 1 and open (OUT,">$outfile");
DEBUG > 1 and print OUT $webdoc->content;
DEBUG > 1 and close(OUT);

# Find date, currency and price using TokeParser

		my ($currency, $date, $price, $pchange, $text, $match, $ucname);
		$htmlstream	=	HTML::TokeParser->new(\$webdoc->content);

		$match = 0;
		while ( ( $tag = $htmlstream->get_tag('caption')) && !$done )
		{
DEBUG and print "\nFound tag : ",$tag->[3],$htmlstream->get_trimmed_text('/caption'),"</caption/>\n";
			while ( ($tag = $htmlstream->get_tag('a')) && $tag->[1]{'href'} && !$match )
			{
DEBUG and print "\nTag-item 'href' = ",$tag->[1]{'href'},"\n";
				if ( $tag->[1]{'href'} =~ m[.*/Factsheets/Factsheet\.aspx.*] )
				{
DEBUG and print "\nFound tag-item : ",$tag->[3],"\n";
					$done = 0;
					$ucname = $htmlstream->get_trimmed_text('/a');
DEBUG and print "\nUpper-case name = ",$ucname,"\n";
					while ( ($tag = $htmlstream->get_tag('td','/tr')) && !$done  )
					{
						if ( $tag->[0] eq '/tr' ) 									# end of table
						{
DEBUG and print "\nEnd of table reached... ";
							$done = 1;
							if ( !$match )
							{
DEBUG and print "no match found on SEDOL/Name\n";
								$currency = $date = $price = undef;
							}
							else
							{
DEBUG and print "SEDOL/Name match found!\n";
							}
						}
						else
						{
							$text = $htmlstream->get_trimmed_text('/td');
							if ( $text =~ m[^([0-9\.]*) \(([a-zA-Z]{1,3})\)] ) 		# price
							{
								$price = $1;
								if ( $2 eq 'p' ) { $currency = 'GBX'; }
								else             { $currency = $2;    }
DEBUG and print "\nCCY / Price = ",$currency," ",$price,"\n";
							}
							if ( $text =~ m[.*([0-9]{2}-[a-zA-Z]{3}-[0-9]{4})] )	# date
							{
								$date = $1;
DEBUG and print "\nDate = ",$date,"\n";
							}
							if ( $text =~ m[^([a-zA-Z0-9]{7})] )					#sedol
							{
DEBUG and print "\nSEDOL = ",$text," : (",$sedol,")\n";
								$text = uc($name);
DEBUG and print "\nNames = ",$ucname," : (",$text,")\n";
								if ( ($sedol eq $1) )					# matches on SEDOL
								{
									$match = 1;
								}
								else
								{
									if ($ucname eq $text)				# matches om name
									{
										$match = 1;
										$fundquote {$code,"errormsg"} = "Warning - matched on name only";
									}
								}
							}
						}
					}
				}
			}
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
DEBUG and print "\n\%-age change = ",$pchange,"\n";

DEBUG and print "\nDate = ",$date,"\n";
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

DEBUG and print "\nPrice = ",$price,"\n";
		if (!defined($price)) {
	    	# serious error, report it and give up
			$fundquote {$code,"success"} = 0;
			$fundquote {$code,"errormsg"} = "Error - failed to find a price";
			next;
		}

DEBUG and print "\nCCY = ",$currency,"\n";
		if (!defined($currency)) {
	    	# serious error, report it and give up
			$fundquote {$code,"success"} = 0;
			$fundquote {$code,"errormsg"} = "Error - failed to find a currency";
			next;
		}

		# defer setting currency and price until we've dealt with possible GBX currency...

# Calculate net change - it's not included in the trustnet factsheets

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

		$fundquote {$code, "method"} = "tnetuk";   # set method

	}

	return wantarray ? %fundquote : \%fundquote;
}

1;

=head1 NAME

Finance::Quote::tnetuk - Obtain UK Unit Trust quotes from trustnet.com.

=head1 SYNOPSIS

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("tnetuk","<isin> ...");  # Only query trustnet.com using ISINs
    %info = Finance::Quote->fetch("ukfunds","<isin>|<sedol>|<mexid> ..."); # Failover to other sources

=head1 DESCRIPTION

This module fetches information from the Trustnet UK Funds service,
http://trustnet.com. There are many UK Unit Trusts and OEICs quoted,
as well as many Offshore Funds and Exhange Traded Funds (ETFs). It converts
any funds quoted in GBX (pence) to GBP, dividing the price by 100 in the
process.

Funds are identified by their ISIN code.

This module is loaded by default on a Finance::Quote object. It's
also possible to load it explicitly by placing "tnetuk" in the argument
list to Finance::Quote->new().

Information obtained by this module may be covered by tnetuk.com
terms and conditions See http://trustnet.com for details.

=head2 Stocks And Indices

This module provides both the "tnetuk" and "ukfunds" fetch methods for
fetching UK and Offshore Unit Trusts and OEICs prices and other information
from funds.ft.com. Please use the "ukfunds" fetch method if you wish to have
failover with future sources for UK and Offshore Unit Trusts and OEICs - the
author has plans to develop Finance::Quote modules for other sources providing
uk unit trust prices. Using the "tnetuk" method will guarantee
that your information only comes from the trustnet.com website.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::TNetuk :

    name, currency, last, date, time, price, nav, source, method,
    iso_date, net, p_change, success, errormsg.


=head1 SEE ALSO




=head1 AUTHOR

Martin Sadler, E<lt>martinsadler@users.sourceforge.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Martin Sadler

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.


=cut

__END__
