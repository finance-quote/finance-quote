#!/usr/bin/perl -w
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@schools.net.au>
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

package Finance::Quote::Yahoo::Europe;
require 5.004;

use strict;
use HTTP::Request::Common;
use LWP::UserAgent;

use vars qw($VERSION $YAHOO_EUROPE_URL);

$VERSION = '0.19';

# URLs of where to obtain information.

$YAHOO_EUROPE_URL = ("http://finance.fr.yahoo.com/d/quotes.csv?f=snl1d1t1c1p2va2bapomwerr1dyj1&s=");

sub methods {return (europe => \&yahoo_europe,yahoo_europe => \&yahoo_europe)};

# =======================================================================
# yahoo_europe gets quotes for European markets from Yahoo.
sub yahoo_europe
{
    my $quoter = shift;
    my @symbols = @_;
    return undef unless @symbols;	# Nothing if no symbols.
    my($x,@q,%aa,$ua,$url,$sym);

    $x = $";
    $" = "+";
    $url = $YAHOO_EUROPE_URL."@symbols";
    $" = $x;
    $ua = $quoter->user_agent;
    my $reply = $ua->request(GET $url);
    return undef unless ($reply->is_success);
    foreach (split('\015?\012',$reply->content))
    {
      @q = $quoter->parse_csv($_);

      $sym = $q[0];
      $aa {$sym, "name"} = $q[1];
      $aa {$sym, "last"} = $q[2];
      $aa {$sym, "date"} = $q[3];
      $aa {$sym, "time"} = $q[4];
      $aa {$sym, "volume"} = $q[7];
      $aa {$sym, "bid"} = $q[9];
      $aa {$sym, "ask"} = $q[10];
      $aa {$sym, "close"} = $q[11];
      $aa {$sym, "open"} = $q[12];
      $aa {$sym, "eps"} = $q[15];
      $aa {$sym, "pe"} = $q[16];
      $aa {$sym, "cap"} = $q[20];

      # Yahoo returns a line filled with N/A's if we look up a
      # non-existant symbol.  AFAIK, the date flag will /never/
      # be defined properly unless we've looked up a real stock.
      # Hence we can use this to check if we've successfully
      # obtained the stock or not.
      if ($aa{$sym,"date"} eq "N/A") {
        $aa{$sym, "success"} = 0;
	$aa{$sym, "errormsg"} = "Stock lookup failed.";
      } else {
        $aa{$sym, "success"} = 1;
      }
    }

    # Return undef's rather than N/As.  This makes things more suitable
    # for insertion into databases, etc.  Also remove silly HTML that
    # yahoo inserts to put in little euro symbols.
    foreach my $key (keys %aa) {
      $aa{$key} =~ s/<[^>]*>//g;
      undef $aa{$key} if (defined($aa{$key}) and $aa{$key} eq "N/A");
    }

    # return wantarray() ? @qr : \@qr;
    return %aa;
}
