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
#    Copyright (C) 2018, Jean-Marie Pacquet <jmpacquet@sourceforge.net>
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
#
# Changelog
#
# 2018-04-08  Jean-Marie Pacquet
#
#     * (1.49) Major site change (html 5)
#
# 2014-01-12  Arnaud Gardelein
#
#     *       changes on website
#
# 2009-04-12  Erik Colson
#
#     *       Major site change.
#
# 2008-11-09  Bernard Fuentes
#
#     *       changes on website
#
# 2006-12-26  Dominique Corbex <domcox@sourceforge.net>
#
#     * (1.4) changes on web site
#
# 2006-09-02  Dominique Corbex <domcox@sourceforge.net>
#
#     * (1.3) changes on web site
#
# 2006-06-28  Dominique Corbex <domcox@sourceforge.net>
#
#     * (1.2) changes on web site
#
# 2006-02-22  Dominique Corbex <domcox@sourceforge.net>
#
#     * (1.0) iniial release
#

require 5.005;

use strict;

package Finance::Quote::Bourso;

use vars qw( $Bourso_URL);

use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TokeParser;
use Text::CSV;

# VERSION

my $Bourso_URL = 'https://www.boursorama.com/cours/';

sub methods {
    return ( bourso => \&bourso
    );
}
{
    my @labels =
        qw/name last date isodate p_change open high low close volume currency method exchange/;

    sub labels {
        return ( bourso => \@labels
        );
    }
}

sub bourso_to_number {
    my $x = shift(@_);
    $x =~ s/\s//g;    # remove spaces etc in number
    return $x;
}

sub bourso {
    my $quoter = shift;
    my @stocks = @_;
    my ( %info, $reply, $url, $te, $ts, $row, $style );
    my $ua = $quoter->user_agent();

    $url = $Bourso_URL;

    foreach my $stocks (@stocks) {
        my $queryUrl = $url . $stocks;
        $reply = $ua->request( GET $queryUrl);

        # print "URL=".$queryUrl."\n";

        if ( $reply->is_success ) {

            # print $reply->content;
            $info{ $stocks, "success" } = 1;

            my $tp = HTML::TokeParser->new(\$reply->content );

            # search 'l-quotepage__header' header division
	    my $header;
	    while ($header = $tp->get_tag( 'header' ))
	    {
		my($tag, $attr, $attrseq, $rawtxt) = @{ $header };
		# print $tag."\t".$attr->{'class'}."\n";
		if ($attr->{'class'} eq 'l-quotepage__header') {
		    last;
		}
	    }
            unless ($header) {
                $info{ $stocks, "success" }  = 0;
                $info{ $stocks, "errormsg" } = "Stock name $stocks not found";
		# print "Stock name $stocks not found\n";
                next;
            }

            # set method
            $info{ $stocks, "method" } = "bourso";

            # retrieve SYMBOL
	    my $div = $tp->get_tag( 'div' );
	    my($tag, $attr, $attrseq, $rawtxt) = @{ $div };
	    my $symbol = $attr->{'data-ist'};
	    if ($symbol) {
		$info{ $stocks, "symbol" } = $symbol;

		# print initial values
		# print $tag."\t".$attr->{'data-ist-init'}."\n";
		# remove surrounding braces
		my $line = substr( $attr->{'data-ist-init'}, 1);
		chop ($line);
		# print $line."\n";
		# retrieve data from csv line
		my $csv = Text::CSV->new ({ escape_char => "\\", allow_loose_quotes => 1, binary => 1 , quote_char => '' })
		    or die "Cannot use CSV: ".Text::CSV->error_diag ();
		my @rows;
		if ($csv->parse($line)) {
		    @rows = $csv->fields();
		    my $i = 0;
		    while ($rows[$i]) {
			my $icsv = Text::CSV->new ({ sep_char => ':' })
			    or die "Cannot use CSV: ".Text::CSV->error_diag ();
			if ($icsv->parse($rows[$i])) {
			    my @elements = $icsv->fields();
			    # print $elements[0]."=".$elements[1]."\n";
			    $info{ $stocks, $elements[0] } = $elements[1];
			    if ($elements[0] eq 'tradeDate') {
				my $year = substr($elements[1],0,4);
				my $month = substr($elements[1],5,2);
				my $day = substr($elements[1],8,2);
				$info{ $stocks, 'date' } = $month."/".$day."/".$year;
				$info{ $stocks, 'isodate' } = $year."-".$month."-".$day;
			    }
			} else {
			    my $ierr = $icsv->error_diag;
			    die "Failed to parse elements: $ierr";
			}
			$i++;
		    }
		} else {
		    my $err = $csv->error_diag;
		    die "Failed to parse line: $err";
		}

		# retrieve NAME
		my $a = $tp->get_tag( 'a' );
		my $name = $tp->get_trimmed_text("/a");
		# print $name."\n";
		$info{ $stocks, "name" } = $name;

		# retrieve CURRENCY (<span class="c-faceplate__price-currency">)
		my $span;
		while ($span = $tp->get_tag( 'span' ))
		{
		    my($tag, $attr, $attrseq, $rawtxt) = @{ $span };
		    # print $tag."\t".$attr->{'class'}."\n";
		    if ($attr->{'class'} eq 'c-faceplate__price-currency') {
			last;
		    }
		}
		my $currency = $tp->get_trimmed_text("/span");
		# print $currency."\n";
		$info{ $stocks, "currency" } = $currency;

	    } else {
		# retrieve NAME & SYMBOL
		my $a = $tp->get_tag( 'a' );
		($tag, $attr, $attrseq, $rawtxt) = @{ $a };
		my $link = $attr->{'href'};
		# print $link."\n";
		my $premier = index($link,'cours/');
		my $dernier = 0;
		if ($premier) {
		    $premier += 6;
		    $dernier = index($link,'/',$premier);
		}
		if ($dernier) {
		    $symbol = substr($link, $premier, $dernier - $premier);
		    # print $symbol."\n";
		    $info{ $stocks, "symbol" } = $symbol;
		}
		
		my $name = $tp->get_trimmed_text("/a");
		# print $name."\n";
		$info{ $stocks, "name" } = $name;

		my $span = $tp->get_tag( 'span' );
		($tag, $attr, $attrseq, $rawtxt) = @{ $span };
		my $last = $tp->get_trimmed_text("/span");
		$info{ $stocks, "last" } = $last;
		$span = $tp->get_tag( 'span' );
		($tag, $attr, $attrseq, $rawtxt) = @{ $span };
		my $currency = $tp->get_trimmed_text("/span");
		$info{ $stocks, "currency" } = $currency;
		while ($div = $tp->get_tag( 'div' ))
		{
		    my($tag, $attr, $attrseq, $rawtxt) = @{ $div };
		    # print $tag."\t".$attr->{'class'}."\n";
		    if ($attr->{'class'} eq 'c-faceplate__real-time') {
			last;
		    }
		}
		if ($div) {
		    my $lastdate = $tp->get_trimmed_text("/div");
		    my $year = substr($lastdate,-4,4);
		    my $month = substr($lastdate,-7,2);
		    my $day = substr($lastdate,-10,2);
		    # print $month."/".$day."/".$year."\n";
		    $info{ $stocks, "date" } = $month."/".$day."/".$year;
		    $info{ $stocks, 'isodate' } = $year."-".$month."-".$day;
		}
	    }

        }
        else {
            $info{ $stocks, "success" }  = 0;
            $info{ $stocks, "errormsg" } = "Error retrieving $stocks ";
        }
    }
    return wantarray() ? %info : \%info;
    return \%info;
}
1;

=head1 NAME

Finance::Quote::Bourso Obtain quotes from Boursorama.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("bourso","ml");  # Only query Bourso

=head1 DESCRIPTION

This module fetches information from the "Paris Stock Exchange",
https://www.boursorama.com. All stocks are available.

This module is loaded by default on a Finance::Quote object. It's
also possible to load it explicity by placing "bourso" in the argument
list to Finance::Quote->new().

Information obtained by this module may be covered by www.boursorama.com
terms and conditions See https://www.boursorama.com/ for details.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::Bourso :
name, last, date, isodate, p_change, open, high, low, close,
volume, currency, method, exchange.

=head1 SEE ALSO

Boursorama (french web site), https://www.boursorama.com

=cut
