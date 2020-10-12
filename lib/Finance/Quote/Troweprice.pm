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
#    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
#    02110-1301, USA
#
#
# This code derived from Padzensky's work on package Finance::YahooQuote,
# but extends its capabilites to encompas a greater number of data sources.
#
# This code was developed as part of GnuCash <http://www.gnucash.org/>

package Finance::Quote::Troweprice;
require 5.005;

use strict;

use vars qw( $TROWEPRICE_URL);

use LWP::UserAgent;
use Time::Piece;
use Try::Tiny;

# VERSION

# URLs of where to obtain information.

$TROWEPRICE_URL = ("https://www3.troweprice.com/fb2/ppfweb/downloadPrices.do");

sub methods { return (troweprice        => \&troweprice,
               troweprice_direct => \&troweprice); }

{
  my @labels = qw/method exchange name nav date isodate price/;

  sub labels { return (troweprice        => \@labels,
               troweprice_direct => \@labels); }
}

# =======================================================================

sub troweprice {

    my $quoter = shift;
    my @symbols = @_;

    return if (! scalar @symbols);

    # for T Rowe Price,  we get them all.
    my %info;
    my $url = $TROWEPRICE_URL;
    my $ua = $quoter->user_agent;
    my $reply = $ua->get( $url, 'Accept-Language' => 'en-US,en' );

    if (! $reply->is_success) {

        for my $stock (@symbols) {
            $info{ $stock, "success" } = 0;
            $info{ $stock, "errormsg" } =
                "Error retrieving quote for $stock. Attempt to fetch the URL
                $url resulted in HTTP response:i " . $reply->status_line;
        }
        return wantarray() ? %info : \%info;
    }

    my $quotes;

    my $csv = $reply->content;
    open my $in, '<', \$csv;
    RECORD:
    while (my $line = <$in>) {
        next RECORD if ($line !~ /\S/);
        #$line =~ s/\s+$//;
        my @q = $quoter->parse_csv($line);
        my $symbol = $q[0];
        next RECORD
            if (! grep {$_ eq $symbol} @symbols);

        my $date;
        try {
            $date = Time::Piece->strptime($q[2], "%m/%d/%Y");
        } catch {
            $info{ $symbol, "success" } = 0;
            $info{ $symbol, "errormsg" } =
                "Failed to parse quote date. Please contact developers";
            next RECORD;
        };
        $quotes->{$symbol} = {
            price => $q[1],
            date  => $date,
        }
    }

    SYMBOL:
    for my $symbol (@symbols) {
        
        # skip if already defined due to earlier parsing error
        next SYMBOL if (defined $info{ $symbol, 'success' });

        if (! defined $quotes->{$symbol}) {
            $info{ $symbol, "success" } = 0;
            $info{ $symbol, "errormsg" } =
                "Error retrieving quote for $symbol - no listing for this"
              . " name found. Please check symbol.";
            next SYMBOL;
        }

        $info{ $symbol, "success"  } = 1;
        $info{ $symbol, 'symbol'   } = $symbol;
        $info{ $symbol, "exchange" } = "T. Rowe Price";
        $info{ $symbol, "method"   } = "troweprice";
        $info{ $symbol, "name"     } = $symbol;  # no name supplied ...
        $info{ $symbol, "nav"      } = $quotes->{$symbol}->{price};
        $info{ $symbol, "price"    } = $info{$symbol,"nav"};
        $info{ $symbol, "currency" } = "USD";
        $quoter->store_date(
            \%info,
            $symbol,
            {isodate => $quotes->{$symbol}->{date}->ymd}
        );
    }

    return wantarray() ? %info : \%info;

}

1;

=head1 NAME

Finance::Quote::Troweprice    - Obtain quotes from T. Rowe Price

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %stockinfo = $q->fetch("troweprice","PRFDX");

=head1 DESCRIPTION

This module obtains information about managed funds from T. Rowe Price.
Information about T. Rowe Price funds is available from a variety of
sources.  This module fetches information directly from T. Rowe Price.

=head1 LABELS RETURNED

Information available from T. Rowe Price may include the following
labels:  exchange, name, nav, date, price.

=head1 SEE ALSO

T. Rowe Price website - http://www.troweprice.com/

=cut
