#!/usr/bin/perl -w
#    This module is based on the Finance::Quote::BSERO module
#    It was first called BOMSE but has been renamed to yahooJSON
#    since it gets a lot of quotes besides Indian
#
#    The code has been modified by Abhijit K to
#    retrieve stock information from Yahoo Finance through json calls
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

package Finance::Quote::BorsaItaliana;

require 5.005;

use strict;
use vars qw($VERSION $YIND_URL_HEAD $YIND_URL_TAIL);
use LWP::UserAgent;
use Web::Scraper;

# VERSION

# URL example = https://www.borsaitaliana.it/borsa/search/scheda.html?code=IT0001086567&lang=it
my $YIND_URL_HEAD = 'https://www.borsaitaliana.it/borsa/search/scheda.html?code=';
my $YIND_URL_TAIL = '&lang=it';

sub methods {
    return ( borsa_italiana => \&borsa_italiana,
    );
}
{
    my @labels = qw/name last date isodate volume currency method exchange type
        div_yield eps pe year_range open high low close/;

    sub labels {
        return ( borsa_italiana => \@labels,
        );
    }
}

sub borsa_italiana {

    my $quoter = shift;
    my @bonds = @_;
    my ( %info, $reply, $url, $te, $ts, $row, @cells, $ce );
    my ( $my_date );
    my $ua = $quoter->user_agent();

    foreach my $bond (@bonds) {

        $url   = $YIND_URL_HEAD . $bond . $YIND_URL_TAIL;
        $reply = $ua->get($url);

        my $code    = $reply->code;
        my $desc    = HTTP::Status::status_message($code);
        my $headers = $reply->headers_as_string;
        my $body    = $reply->content;

        #Response variables available:
        #Response code: 	$code
        #Response description: 	$desc
        #HTTP Headers:		$headers
        #Response body		$body

        $info{ $bond, "symbol" } = $bond;

        if ( $code == 200 ) {

            my $widget = scraper {
                process 'div.summary-value span.t-text', 'val' => 'TEXT';
            };

            my $result = $widget->scrape($reply);
            # check if found
            unless (exists $result->{val}) {
                $info{$bond, 'success'} = 0;
                $info{$bond, 'errormsg'} = 'Failed to find ISIN';
                next;
            }

            my $value = $result->{val};
            $value =~ s/[^0123456789,]//g;
            $value =~ s/,/./g;

            $widget = scraper {
                process 'title', 'name' => 'TEXT';
            };

            $result = $widget->scrape($reply);
            # check if found
            unless (exists $result->{name}) {
                $info{$bond, 'success'} = 0;
                $info{$bond, 'errormsg'} = 'Failed to find ISIN';
                next;
            }

            my $name = $result->{name};
            $name =~ s/quotazioni in tempo reale .* Borsa Italiana//g;

            $widget = scraper {
                process 'div.summary-fase span.t-text', 'dt[]' => 'TEXT';
            };

            $result = $widget->scrape($reply);
            # check if found
            unless (exists $result->{dt}) {
                $info{$bond, 'success'} = 0;
                $info{$bond, 'errormsg'} = 'Failed to find ISIN';
                next;
            }

            my $date = $result->{dt}[1];
            $date =~ s/.*Contratto:\ //g;
            $date =~ s/[^0123456789]//g;
            my ($dd,$mm,$yy,$hh,$mi,$ss) = $date =~ /^([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{1,})([0-9]{2})([0-9]{2})\z/ or die;
            my $my_date= $dd.".".$mm.".".$yy." ".$hh.":".$mi.":".$ss;

            $info{ $bond, "success" }  = 1;
            $info{ $bond, "exchange" } = "Borsa Italiana";
            $info{ $bond, "method" }   = "borsa_italiana";
            $info{ $bond, "name" }     = $name;
            $info{ $bond, "symbol" }   = $bond;
            $info{ $bond, "price" }    = $value;
            $info{ $bond, "last" }     = $value;
            $info{ $bond, "currency" } = "EUR";

            $quoter->store_date( \%info, $bond,
                                     { eurodate => $my_date } );
        }

        #HTTP request fail
        else {
            $info{ $bond, "success" } = 0;
            $info{ $bond, "errormsg" } =
                "Error retrieving quote for $bond. Attempt to fetch the URL $url resulted in HTTP response $code ($desc)";
        }

    }

    return wantarray() ? %info : \%info;
    return \%info;
}

1;

=head1 NAME

Finance::Quote::BorsaItaliana - Obtain quotes from Borsa Italiana site

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("borsa_italiana","{ISIN_CODE}");

=head1 DESCRIPTION

This module fetches information from Borsa Italiana site

This module is loaded by default on a Finance::Quote object. It's
also possible to load it explicitly by placing "BorsaItaliana" in the argument
list to Finance::Quote->new().

This module provides the "borsa_italiana" fetch method.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::BorsaItaliana :
name, symbol, price, last, isodate, currency, method, exchange.

=head1 SEE ALSO

=cut
