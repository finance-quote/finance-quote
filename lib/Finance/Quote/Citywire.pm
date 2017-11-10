#!/usr/bin/perl -w

#  Citywire.pm
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
#    Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
#    02111-1307, USA
#


package Finance::Quote::Citywire;
require 5.005;

use strict;
use warnings;

# Set DEBUG => 0 for no debug messages, => 1 for first level, => 2 for 2nd level, etc.

use constant DEBUG => 0;

# URLs
use vars qw($VERSION $CITYWIRE_NEXT_URL $CITYWIRE_LOOK_UP $CITYWIRE_MAIN_URL);

use LWP::Simple;
use LWP::UserAgent;
use HTTP::Request::Common;
use HTTP::Cookies;
use HTML::TokeParser;
# use Data::Dumper;

# VERSION

$CITYWIRE_MAIN_URL   =   "http://citywire.co.uk";
$CITYWIRE_LOOK_UP    =   "http://citywire.co.uk/money/search.aspx?phrase=";
$CITYWIRE_NEXT_URL	=	"";

# FIXME -

sub methods { return (citywire => \&citywire_fund,
		      			ukfunds => \&citywire_fund); }

{
    my @labels = qw/name currency last date time price nav source iso_date method net p_change success errormsg/;

    sub labels { return (citywire => \@labels,
			 				ukfunds => \@labels); }
}

#
# =======================================================================

sub citywire_fund  {
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

        my $webdoc  = $ua->get($CITYWIRE_LOOK_UP.$code);
        if (!$webdoc->is_success)
        {
	        # serious error, report it and give up
		    $fundquote {$code,"success"} = 0;
		    $fundquote {$code,"errormsg"} =
		        "Error - failed to retrieve fund data : HTTP Status = ",$webdoc->status_line;
		    next;
	    }
	    $fundquote {$code, "symbol"} = $code;
	    $fundquote {$code, "source"} = $CITYWIRE_MAIN_URL;

DEBUG and print "\nTitle  = ",$webdoc->title,"\n";
DEBUG and print "\nStatus = ",$webdoc->status_line, "\n";
DEBUG > 1 and print "\nCookie Jar = : \n",Dumper($cj),"\n\n";

# Find name and next url using TokeParser

		my $htmlstream	=	HTML::TokeParser->new(\$webdoc->content);

        my ($name, $nexturl);
		while ( (my $tag = $htmlstream->get_tag('a')) && !$nexturl)
		{
			if ( $tag->[1]{'title'} )
			{
				if ( $tag->[1]{'title'} eq 'view Fact Sheet' )
				{
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

# modify $nexturl to remove html escape encoding for the Ampersand (&) character

		$nexturl =~ s/&amp;/&/;

# Now need to look-up next page using $next_url

        $webdoc  = $ua->get($CITYWIRE_MAIN_URL.$nexturl);
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
DEBUG > 1 and print "\nCookie Jar = : \n",Dumper($cj),"\n\n";

# Find date, currency and price using TokeParser

		my ($currency, $date, $price, $pchange);
		$htmlstream	=	HTML::TokeParser->new(\$webdoc->content);

		my $done = 0;
		while ( (my $tag = $htmlstream->get_tag('div')) && !$done)
		{
			if ( $tag->[1]{'class'} )
			{
				if ( $tag->[1]{'class'} eq 'fundQuickInfo' )
				{
DEBUG and print "\nFound tag : ",$tag->[3],"\n";
					$tag = $htmlstream->get_tag('h5');
					my $text = $htmlstream->get_trimmed_text('/h5');
DEBUG and print "\nFound tag : ",$tag->[3],$text,"</h5>\n";
					if ( $text eq "LATEST PRICE" )
					{
						$tag = $htmlstream->get_tag('p');
						$text = $htmlstream->get_trimmed_text('/p');
DEBUG and print "\nFound tag : ",$tag->[3],$text,"</p>\n";
						if ( $text =~ m[.*([0-9]{2}/[0-9]{2}/[0-9]{4})] )
						{
							$date = $1;
						}
					}
					$tag = $htmlstream->get_tag('li');
					$text = $htmlstream->get_trimmed_text('/li');
DEBUG and print "\nFound tag : ",$tag->[3],$text,"</li>\n";
DEBUG and print "\n\$text = ",$text,"\n";
					if ( $tag->[1]{'class'} eq 'price currency' )
					{
						if ( $text =~ m[([\D]+)([0-9\.]+)] )
						{
							$price = $2;
DEBUG and print "\n\$1 = ",$1,"\n";
DEBUG and print "\n\$2 = ",$2,"\n";
							if ( $1 eq "£" )
							{
								$currency = "GBP";
							}
							else
							{
								if( $1 =~ m[([A-Z]{3})] ) { $currency = $1; }
							}
						}
					}
					$tag = $htmlstream->get_tag('h5');
					$text = $htmlstream->get_trimmed_text('/h5');
DEBUG and print "\nFound tag : ",$tag->[3],$text,"</h5>\n";
					if ( $text eq "CHANGE IN PRICE" )
					{
						$tag = $htmlstream->get_tag('li');
						$text = $htmlstream->get_trimmed_text('/li');
DEBUG and print "\nFound tag : ",$tag->[3],$text,"</li>\n";
						if ( $tag->[1]{'class'} =~ m[^price ([a-z]*)] )
						{
							my $negate = $1;
							if ( $text =~ m[([0-9\.]+)\%] )
							{
								$pchange = $1;
							}
							if ( $negate eq 'minus')
							{
								$pchange = 0 - $pchange;
							}
						}
					}
				}
			}
		}

DEBUG and print "\n\%-age change = ",$pchange,"\n";
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

		$fundquote {$code, "method"} = "citywire";   # set method

	}

	return wantarray ? %fundquote : \%fundquote;
}

1;

=head1 NAME

Finance::Quote::citywire - Obtain UK Unit Trust quotes from morningstar.co.uk.

=head1 SYNOPSIS

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("citywire","<isin> ...");  # Only query morningstar.co.uk using ISINs
    %info = Finance::Quote->fetch("ukfunds","<isin>|<sedol>|<mexid> ..."); # Failover to other sources

=head1 DESCRIPTION

This module fetches information from the Citywire Funds service,
http://citywire.co.uk. There are many UK Unit Trusts and OEICs quoted,
as well as many Offshore Funds and Exhange Traded Funds (ETFs). It converts
any funds quoted in GBX (pence) to GBP, dividing the price by 100 in the
process.

Funds are identified by their ISIN code.

This module is loaded by default on a Finance::Quote object. It's
also possible to load it explicitly by placing "citywire" in the argument
list to Finance::Quote->new().

Information obtained by this module may be covered by citywire.co.uk
terms and conditions See http://citywire.co.uk for details.

=head2 Stocks And Indices

This module provides both the "citywire" and "ukfunds" fetch methods for
fetching UK and Offshore Unit Trusts and OEICs prices and other information
from funds.ft.com. Please use the "ukfunds" fetch method if you wish to have
failover with future sources for UK and Offshore Unit Trusts and OEICs - the
author has plans to develop Finance::Quote modules for other sources providing
uk unit trust prices. Using the "citywire" method will guarantee
that your information only comes from the citywire.co.uk website.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::Citywire :

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
