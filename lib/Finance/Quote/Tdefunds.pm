#!/usr/bin/perl -w
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@cpan.org>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#    Copyright (C) 2001, James Treacy <treacy@debian.org>
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
package Finance::Quote::Tdefunds;
require 5.005;

use strict;

use vars qw($VERSION $TD_URL);

use LWP::UserAgent;
use HTTP::Request::Common;
use Carp;

$VERSION = '1.00';

# URLs of where to obtain information.

#$TD_URL = ("http://tdfunds.tdam.com/tden/FundProfile/FundProfile.cfm");
#$TD_URL = ("http://tdfunds.tdam.com/tden/Download/v_DownloadProcess.cfm?SortField=FundName&SortOrder=ASC&Nav=No&Group=99&WhereClause=Where%20FC%2EFund%5FClass%5FORDER%20%3C%2099%20and%20TD%2ERisk%5FCat%5FID%20%21%3D%204&DownloadType=CSV");
$TD_URL = ("http://www.tdassetmanagement.com/TDAMFunds/Download/v_Download.asp?TAB=PRICE&PID=10&DT=csv&SORT=TDAM_FUND_NAME&FT=all&MAP=N&SI=4");

my(%currencies) = (
	"CDN"	=>	"CAD",
	"US"	=>	"USD"
);

sub methods { return (tdefunds => \&tdefunds); }

sub labels { return (tdefunds => [qw/method exchange name nav date isodate price/]); }

# =======================================================================

#
# Converts a description to a stock-like symbol
#
sub tdefunds_create_symbol {
	my($name) = shift;

	# Take out any bad characters
	$name =~ s/[^a-zA-Z\.\^\ \*]//g;

	# Multiple consecutive speces converted to a single space.
	$name =~ s/\s+/ /g;

	return $name;

	# return "TDSCITECH";
}

#
# Maps the provided currency, where possible, to the correct ISO code.
#
sub tdefunds_get_currency {
    my($currency) = shift;

    $currency =~ s/\$//g;
    $currency =~ s/\s//g;

    if ( defined($currencies{$currency}) ) {
        $currency = $currencies{$currency};
    }

    return $currency;
}

sub tdefunds
{
    my $quoter = shift;
    my(@q,%aa,$ua,$url,$sym,$price);

    $url = $TD_URL;
    $ua = $quoter->user_agent;
    my $reply = $ua->request(GET $url);
    return unless ($reply->is_success);
    foreach (split('\015?\012',$reply->content))
    {
        @q = $quoter->parse_csv($_);

	# Skip the non-data rows.
	next if (!defined($q[0]) || !defined($q[1])); # Skip the section headers
	next if $q[0] =~ /^Fund Number/; # Skip the title

        ($sym = $q[1]) =~ s/^ +//;
        if ($sym) {

	    # make sure what we get looks like an acceptable stock symbol
	    # only allow a-z + '.' + "^"
	    my($name) = $sym;
            $sym = &tdefunds_create_symbol($sym);

	    # $sym =~ tr/a-z/A-Z/;
	    $aa {$sym, "exchange"} = "TD Waterhouse";  # TRP
	    $aa {$sym, "method"} = "tdefunds";
	    $aa {$sym, "name"} = $name;
	    $price = $q[3];
	    $price =~ s/\$//;
            $price =~ s/^ +//;
	    $aa {$sym, "last"} = $price;
	    $quoter->store_date(\%aa, $sym, {usdate => $q[2]});
	    $aa {$sym, "nav"} = $aa{$sym,"last"};
	    $aa {$sym, "success"} = 1;
	    $aa {$sym, "currency"} = &tdefunds_get_currency($q[4]);
        } else {
	    $aa {$sym, "success"} = 0;
	    $aa {$sym, "errormsg"} = "Fund lookup failed.";
	}
    }

    return %aa if wantarray;
    return \%aa;
}

1;

=head1 NAME

Finance::Quote::Tdefunds	- Obtain quotes from TD Waterhouse Efunds

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %quotes = $q->tdefunds ("TD Canadian Index");
    $date = $quotes {"TD Canadian Index", "date"};
    $nav = $quotes {"TD Canadian Index", "nav"};
    print "TD Canadian Index $date: NAV = $nav\n";
    $nav = $quotes {"TD Canadian Index", "nav"};

=head1 DESCRIPTION

This module obtains information about managed funds from TD
Waterhouse Canada Efunds. All TD Waterhouse efunds are downloaded at once. 

The symbols for each efund are the names of the efund with any
unusal characters (not a letter, space or period) removed. For example;
a fund called "TD US Index ($US)" would have the symbol
"TD US Index US". 

=head1 LABELS RETURNED

Information available from TD Waterhouse may include the following
labels:  exchange, name, nav, date, price, currency.

=head1 SEE ALSO

TD Waterhouse website - http://www.tdwaterhouse.ca/

=cut
