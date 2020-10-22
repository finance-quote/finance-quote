#!/usr/bin/perl -w
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#    Copyright (C) 2001, Leigh Wedding <leigh.wedding@telstra.com>
#    Copyright (C) 2000-2004, Paul Fenwick <pjf@cpan.org>
#    Copyright (C) 2014, Chris Good <chris.good@@ozemail.com.au>
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

require 5.005;

use strict;
use warnings;

package Finance::Quote::ASX;

use LWP::UserAgent;
use JSON qw/decode_json/;

use vars qw/$ASX_URL $ASX_URL_FALLBACK/;

# VERSION

$ASX_URL = 'https://www.asx.com.au/asx/1/share';
$ASX_URL_FALLBACK =
    'https://asx.api.markitdigital.com/asx-research/1.0/companies';


sub methods {return (australia => \&asx,asx => \&asx)}

{
    my @labels = qw/
        last
        net
        p_change
        bid
        offer
        open
        close
        high
        low
        volume
        price
        method
        exchange/;

    sub labels { return (australia => \@labels,
                         asx       => \@labels); }
}

# Australian Stock Exchange (ASX)
# The ASX provides free delayed quotes through their webpage.
#
# Maintainer of this section is Paul Fenwick <pjf@cpan.org>
# 5-May-2001 Updated by Leigh Wedding <leigh.wedding@telstra.com>
# 24-Feb-2014 Updated by Chris Good <chris.good@@ozemail.com.au>
# 12-Oct-2020 Updated by Jeremy Volkening

sub asx {

    my $quoter = shift;
    my @symbols = @_
        or return;

    my %info;

    my $ua = $quoter->user_agent;

    SYMBOL:
    for my $symbol (@symbols) {

        # there are multiple endpoints returning JSON data on a security. The
        # primary endpoint returns the most readily-consumable data and works
        # for most securities, so try that first

        my $res = $ua->get(
            join( '/', $ASX_URL, $symbol),
            'Accept' => 'application/json'
        );
        if ($res->header('content-type') =~ /application\/json/) {
            my $data = decode_json( $res->content );
            if ($res->is_success && defined $data->{last_price}) {
                $info{ $symbol, 'success'  } = 1;
                $info{ $symbol, 'symbol'   } = $symbol;
                $info{ $symbol, 'last'     } = $data->{last_price};
                $info{ $symbol, 'net'      } = $data->{change_price};
                $info{ $symbol, 'p_change' } = $data->{change_in_percent};
                $info{ $symbol, 'p_change' } =~ s/\%$//; # strip suffix
                $info{ $symbol, 'bid'      } = $data->{bid_price};
                $info{ $symbol, 'offer'    } = $data->{offer_price};
                $info{ $symbol, 'open'     } = $data->{open_price};
                $info{ $symbol, 'close'    } = $data->{previous_close_price};
                $info{ $symbol, 'high'     } = $data->{day_high_price};
                $info{ $symbol, 'low'      } = $data->{day_low_price};
                $info{ $symbol, 'volume'   } = $data->{volume};
                $info{ $symbol, 'price'    } = $data->{last_price};
                $info{ $symbol, 'method'   } = 'asx',
                $info{ $symbol, 'exchange' } = 'Australian Securities Exchange',
                $info{ $symbol, 'currency' } = 'AUD',
                my $date = $data->{last_trade_date};
                my $t = Time::Piece->strptime($date, '%Y-%m-%dT%H:%M:%S%z');
                $quoter->store_date(
                    \%info,
                    $symbol,
                    { isodate => $t->ymd }
                );
            }
            else {
                $info{ $symbol, 'success'  } = 0;
                $info{ $symbol, 'errormsg' } = "The security $symbol is not"
                    . " available from this endpoint";
            }
        }
        else {
            $info{ $symbol, 'success'  } = 0;
            $info{ $symbol, 'errormsg' } = "Unable to fetch data from the
            server. HTTP status: " . $res->status_line;
        }

        # this secondary endpoint contains the security name, and for a few
        # securities that fail above may contain limited price data. For
        # instance, the indexes seem to not be available above but will return
        # basic data here

        $res = $ua->get(
            join( '/', $ASX_URL_FALLBACK, $symbol, 'header'),
            'Accept' => 'application/json'
        );
        if ($res->is_success && $res->header('content-type') =~ /application\/json/) {
            my $data = decode_json( $res->content )->{data};
            $info{ $symbol, 'name'     } = $data->{displayName};
            if (! $info{ $symbol, 'success'  }) {
                delete $info{ $symbol, 'errormsg'  }; # set previously
                $info{ $symbol, 'success'  } = 1;
                $info{ $symbol, 'symbol'   } = $symbol;
                $info{ $symbol, 'last'     } = $data->{priceLast};
                $info{ $symbol, 'net'      } = $data->{priceChange};
                $info{ $symbol, 'p_change' } = $data->{priceChangePercent};
                $info{ $symbol, 'volume'   } = $data->{volume};
                $info{ $symbol, 'price'    } = $data->{priceLast};
                $info{ $symbol, 'method'   } = 'asx';
                $info{ $symbol, 'exchange' } = 'Australian Securities Exchange';
                # $info{ $symbol, 'currency' } = 'AUD', # apparently shouldn't be set?
            }

        }
            
    }

    return %info if wantarray;
    return \%info;

}

1;

=head1 NAME

Finance::Quote::ASX - Obtain quotes from the Australian Stock Exchange.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %stockinfo = $q->fetch("asx","BHP");       # Only query ASX.
    %stockinfo = $q->fetch("australia","BHP"); # Failover to other sources OK.

=head1 DESCRIPTION

This module obtains information from the Australian Stock Exchange
http://www.asx.com.au/.  All Australian stocks and indicies are
available.  Indexes start with the letter 'X'.  For example, the
All Ordinaries is "XAO".

This module is loaded by default on a Finance::Quote object.  It's
also possible to load it explicitly by placing "ASX" in the argument
list to Finance::Quote->new().

This module provides both the "asx" and "australia" fetch methods.
Please use the "australia" fetch method if you wish to have failover
with other sources for Australian stocks (such as Yahoo).  Using
the "asx" method will guarantee that your information only comes
from the Australian Stock Exchange.

Information returned by this module is governed by the Australian
Stock Exchange's terms and conditions.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::ASX:
bid, offer, open, high, low, last, net, p_change, volume,
and price.

=head1 SEE ALSO

Australian Stock Exchange, http://www.asx.com.au/

Finance::Quote::Yahoo::Australia.

=cut
