#!/usr/bin/perl -w
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@cpan.org>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
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

package Finance::Quote::Troweprice;
require 5.004;

use strict;

use vars qw($VERSION $TROWEPRICE_URL);

use LWP::UserAgent;
use HTTP::Request::Common;
use Carp;

$VERSION = '0.19';

# URLs of where to obtain information.

$TROWEPRICE_URL = ("http://www.troweprice.com/funds/prices.csv");

sub methods { return (troweprice => \&troweprice); }

sub labels { return (troweprice => [qw/exchange name nav date price/]); }

# =======================================================================

sub troweprice
{
    my $quoter = shift;
    my(@q,%aa,$ua,$url,$sym);

    # for T Rowe Price,  we get them all. 
    $url = $TROWEPRICE_URL;
    $ua = $quoter->user_agent;
    my $reply = $ua->request(GET $url);
    return unless ($reply->is_success);
    foreach (split('\015?\012',$reply->content))
    {
        @q = $quoter->parse_csv($_);

        # extract the date which is usually on the second line fo the file.
        ($sym = $q[0]) =~ s/^ +//;
        if ($sym) {
            $aa {$sym, "exchange"} = "T. Rowe Price";  # TRP
            # ($aa {$sym, "name"} = $q[0]) =~ s/^ +//;
            $aa {$sym, "name"} = $sym;  # no name supplied ... 
            $aa {$sym, "nav"} = $q[1];
            $aa {$sym, "date"} = $q[2];
	    $aa {$sym, "price"} = $aa{$sym,"nav"};
	    $aa {$sym, "success"} = 1;
            $aa {$sym, "currency"} = "USD";
        } else {
	    $aa {$sym, "success"} = 0;
	    $aa {$sym, "errormsg"} = "Stock lookup failed.";
	}
    }

    return %aa if wantarray;
    return \%aa;
}

1;
