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

package Finance::Quote::Fidelity;
require 5.005;

use strict;
use vars qw/$FIDELITY_URL $VERSION/;

use LWP::UserAgent;
use HTTP::Request::Common;

$VERSION = '1.05';

$FIDELITY_URL = ("http://activequote.fidelity.com/nav/fulllist.csv");

sub methods {return (fidelity        => \&fidelity,
                     fidelity_direct => \&fidelity);}

{
	my @labels = qw/exchange name number nav change ask
                        date isodate yield price method/;

	sub labels { return (fidelity        => \@labels,
	                     fidelity_direct => \@labels); }
}

# =======================================================================
# the fidelity routine gets quotes from fidelity investments
#
sub fidelity
{
    my $quoter = shift;
    my @symbols = @_;
    return unless @symbols;
    my(%aa, @q, $sym, $k, $ua, $reply);

    # Build a small hash of symbols people want, because it provides a
    # quick and easy way to only return desired symbols.

    my %symbolhash;
    %symbolhash = map{$_, 1} @symbols;

    # the fidelity pages are comma-separated-values (csv's)
    # Grab the page with all funds listed
    $ua = $quoter->user_agent;
    $reply = $ua->request(GET $FIDELITY_URL);
    if ($reply->is_success) {
      foreach (split('\015?\012',$reply->content)) {
	my @q = $quoter->parse_csv($_) or next;
	
	$sym = $q[2] or next;
	$sym =~ s/^ +//;
    
    	# Skip symbols we didn't ask for.
    	next unless (defined($symbolhash{$sym}));
    
	 $aa {$sym, "exchange"}	= "Fidelity";  # Fidelity
	 $aa {$sym, "method"}  	= "fidelity_direct";
	($aa {$sym, "name"}    	= $q[0]) =~ s/^\s+//;
	 $aa {$sym, "name"}    	=~ s/\s+$//;
	 $aa {$sym, "symbol"}  	= $sym;
	($aa {$sym, "number"}  	= $q[1]) =~ s/^\s+//;
	($aa {$sym, "nav"}     	= $q[4]) =~ s/^\s+// 	if defined($q[4]);
	($aa {$sym, "div"}     	= $q[5]) =~ s/^\s+// 	if defined($q[5]);
	($aa {$sym, "net"}     	= $q[6]) =~ s/^\s+// 	if defined($q[6]);
	($aa {$sym, "p_change"} = $q[8]) =~ s/^\s+// 	if defined($q[8]);
	($aa {$sym, "yield"}    = $q[9]) =~ s/^\s+// 	if defined($q[9]);
	($aa {$sym, "yield"}    = $q[17]) =~ s/^\s+// 	if defined($q[17]);
	 $aa {$sym, "price"}    = $aa{$sym, "nav"} 	if defined($q[4]);
	 $aa {$sym, "success"}  = 1;
	 $aa {$sym, "currency"} = "USD";
	 $quoter->store_date(\%aa, $sym, {usdate => $q[19]});
      }
    }

    return %aa if wantarray;
    return \%aa;
}


1;

=head1 NAME

Finance::Quote::Fidelity - Obtain information from Fidelity Investments.

=head1 NOTE NOTE NOTE NOTE NOTE

This module is currently non-functional.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("fidelity","FBGRX");
    %info = Finance::Quote->fetch("fidelity_direct","FBGRX");

=head1 DESCRIPTION

This module obtains information from Fidelity Investments,
http://www.fidelity.com/.  This module is loaded by default on
the Finance::Quote object.  It is also possible to load this
module explicitly by passing "Fidelity" as one of
Finance::Quote->new()'s parameters.

The "fidelity" fetch method may make use of failover modules.
The "fidelity_direct" method will only obtain information
directly from Fidelity.

Information returned by this module is governed by Fidelity
Investment's terms and conditions.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::Fidelity:
exchange, name, number, nav, change, ask, date, yield, price.

=head1 SEE ALSO

Fidelity Investments, http://www.fidelity.com/

Finance::Quote::Yahoo::USA;

=cut
