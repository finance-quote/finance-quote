#!/usr/bin/perl -w
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@cpan.org>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#    Copyright (C) 2001, Rob Sessink <rob_ses@users.sourceforge.net>
#    Copyright (C) 2005, Morten Cools <morten@cools.no>
#    Copyright (C) 2006, Dominique Corbex <domcox@sourceforge.net>
#    Copyright (C) 2008, Bernard Fuentes <bernard.fuentes@gmail.com>
#    Copyright (C) 2009, Erik Colson <eco@ecocode.net>
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
# 2017-01-10  Julian Wollrath <jwollrath@web.de>
#
#     * (0.1) iniial release
#

package Finance::Quote::OnVista;
require 5.005;

use strict;
use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TreeBuilder;
use Encode;

# VERSION

use vars qw($OnVista_URL);

my $OnVista_URL = 'https://www.onvista.de';

sub methods {return (onvista => \&onvista);}
sub labels {return ( onvista => [qw/name last date isodate time currency method exchange/] );}

sub onvista {
    my $quoter = shift;
    my @stocks = @_;
    my (%info, $reply);
    my $ua = $quoter->user_agent();

    foreach my $stock (@stocks) {
        my $queryUrl = "$OnVista_URL/suche/$stock";
        $reply = $ua->request(GET $queryUrl);

        eval {
            my $tree    = HTML::TreeBuilder->new_from_content(decode_utf8 $reply->content);
            my $row     = $tree->look_down('_tag' => 'tr', 'class' => 'HERVORGEHOBEN');
            my $link    = $row->look_down('_tag' => 'a');
            $queryUrl   = $OnVista_URL . $link->attr('href');
            $reply      = $ua->request(GET $queryUrl);
        };

        if ($@) {
            $info{ $stock, "success" }  = 0;
            $info{ $stock, "errormsg" } = "Error retreiving $stock redirect: $@";
        }

        if ($reply->is_success) {

            $info{ $stock, "success" } = 1;

            my $tree = HTML::TreeBuilder->new_from_content(decode_utf8 $reply->content);

            my @nameline = $tree->look_down('property', 'schema:name');

            if (not @nameline) {
                @nameline = $tree->look_down('class', 'inline name');
		if (not @nameline) {
                    @nameline = $tree->look_down('class', 'ui medium header');
                }
            }

            unless (@nameline) {
                $info{ $stock, "success" } = 0;
                $info{ $stock, "errormsg" } = "Stock name $stock not retrievable";
                next;
            }

            my $name = $nameline[0]->as_text;
            $name =~ s/^\s+|\s+$//g;
            $info{ $stock, "name" } = $name;

            $info{ $stock, "method" } = "onvista";

            my $exchange = $tree->look_down('property', 'schema:seller');
            if ($exchange) {
                $info{ $stock, "exchange" } = $exchange->attr_get_i('content');
            }

            my @currencyline = $tree->look_down('property', 'schema:priceCurrency');
            if (not @currencyline) {
                @currencyline = $tree->look_down('id', 'current-quote-currency');
            }
	    if (@currencyline) {
                my $currency = $currencyline[0]->as_text;
                $info{ $stock, "currency" } = $currency;
            } else {
                @currencyline = $tree->look_down('class', 'price');
                my $currency = ( $currencyline[0]->content_list )[0];
		$currency =~ s/.* //;
                $info{ $stock, "currency" } = $currency;
            }

            my @lastline = $tree->look_down('data-push', qr/.*last.*Stock/);
            if (not @lastline) {
                @lastline = $tree->look_down('id', 'current-quote-price');
            }
            if (not @lastline) {
                @lastline = $tree->look_down('class', 'price');
		if (@lastline) {
                    my $last = ( $lastline[0]->content_list )[0];
                    $last =~ s/,/./;
                    $last =~ s/ .*//;
                    $info{ $stock, "last" } = $last;
	        } else {
		    my $last = $tree->look_down('property', 'schema:price');
		    if ($last) {
			$info{ $stock, "last" } = $last->attr_get_i('content');
		    }
		}
            } else {
                my $last = $lastline[0]->as_text;
                $last =~ s/,/./;
                $info{ $stock, "last" } = $last;
            }

            my @datetimeline = $tree->find_by_tag_name('cite');
            if (not @datetimeline) {
                @datetimeline = $tree->look_down('id', 'current-quote-datetime');
		if (@datetimeline) {
                    my $datetime = $datetimeline[0]->as_text;
                    my $date = substr($datetime, 4, 2)."/".substr($datetime, 1, 2)."/".substr($datetime, 7, 4);
                    my $time = substr($datetime, 13, 8);
                    $info{ $stock, "date" } = $date;
                    $info{ $stock, "time" } = $time;
                } else {
                    @datetimeline = $tree->look_down('class', 'datetime');
                    my $datetime = ( $datetimeline[0]->content_list )[0];
                    my $date = substr($datetime, 3, 2)."/".substr($datetime, 0, 2)."/".substr($datetime, 6, 4);
                    my $time = substr($datetime, 12, 8);
                    $info{ $stock, "date" } = $date;
                    $info{ $stock, "time" } = $time;
                }
            } else {
                my $datetime = $datetimeline[0]->as_text;
                my $date = substr($datetime, 5, 2)."/".substr($datetime, 2, 2)."/".substr($datetime, 8, 4);
                my $time = substr($datetime, 14, 8);
                $info{ $stock, "date" } = $date;
                $info{ $stock, "time" } = $time;
            }

            $quoter->store_date(\%info, $stock, {usdate => $info{$stock, "date"}});
            $tree->delete;
        }
        else {
            $info{ $stock, "success" }  = 0;
            $info{ $stock, "errormsg" } = "Error retreiving $stock";
        }
    }
    return wantarray() ? %info : \%info;
    return \%info;
}
1;

=head1 NAME

Finance::Quote::OnVista Obtain quotes from OnVista.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("onvista","ml");  # Only query OnVista

=head1 DESCRIPTION

This module fetches information from OnVista, https://www.onvista.de. All stocks are available.

This module is loaded by default on a Finance::Quote object. It's
also possible to load it explicity by placing "onvista" in the argument
list to Finance::Quote->new().

Information obtained by this module may be covered by www.onvista.de
terms and conditions See https://www.onvista.de/ for details.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::OnVista :
name, last, date, isodate, time, currency, method, exchange.

=head1 SEE ALSO

OnVista (german web site), https://www.onvista.de

=cut
