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
package Finance::Quote::Tdwaterhouse;
require 5.005;

use strict;

use vars qw($VERSION $TD_URL);

use LWP::UserAgent;
use HTTP::Request::Common;
use Carp;

$VERSION = '1.00';

# URLs of where to obtain information.

#$TD_URL = ("http://tdfunds.tdam.com/tden/FundProfile/FundProfile.cfm");
$TD_URL = ("http://tdfunds.tdam.com/tden/Download/v_DownloadProcess.cfm?SortField=FundName&SortOrder=ASC&Nav=No&Group=99&WhereClause=Where%20FC%2EFund%5FClass%5FORDER%20%3C%2099%20and%20TD%2ERisk%5FCat%5FID%20%21%3D%204&DownloadType=CSV");

sub methods { return (tdwaterhouse => \&tdwaterhouse); }

sub labels { return (tdwaterhouse => [qw/method exchange name nav date price/]); }

# =======================================================================

sub tdwaterhouse
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

        ($sym = $q[1]) =~ s/^ +//;
        if ($sym) {
	    $aa {$sym, "exchange"} = "TD Waterhouse";  # TRP
	    $aa {$sym, "method"} = "tdwaterhouse";
	    $aa {$sym, "name"} = $sym;
	    $price = $q[3];
	    $price =~ s/\$//;
	    $aa {$sym, "nav"} = $price;
	    $aa {$sym, "date"} = $q[2];
	    $aa {$sym, "price"} = $aa{$sym,"nav"};
	    $aa {$sym, "success"} = 1;
	    $aa {$sym, "currency"} = $q[4];
        } else {
	    $aa {$sym, "success"} = 0;
	    $aa {$sym, "errormsg"} = "Stock lookup failed.";
	}
    }

    return %aa if wantarray;
    return \%aa;
}

1;

=head1 NAME

Finance::Quote::Tdwaterhouse	- Obtain quotes from TD Waterhouse Canada

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %quotes = $q->tdwaterhouse ("TD AmeriGrowth RSP");
    $date = $quotes {"TD AmeriGrowth RSP", "date"};
    $nav = $quotes {"TD AmeriGrowth RSP", "nav"};
    print "TD AmeriGrowth RSP for $date: NAV = $nav\n";
    $nav = $quotes {"TD AmeriGrowth RSP", "nav"};

=head1 DESCRIPTION

This module obtains information about managed funds from TD
Waterhouse Canada. All TD Waterhouse funds are downloaded at once. 

=head1 LABELS RETURNED

Information available from TD Waterhouse may include the following
labels:  exchange, name, nav, date, price, currency.

=head1 SEE ALSO

TD Waterhouse website - http://www.tdwaterhouse.ca/

=cut
