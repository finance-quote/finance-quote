#!/usr/bin/perl -W
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@cpan.org>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#    Copyright (C) 2000, Volker Stuerzl <volker.stuerzl@gmx.de>
#    Copyright (C) 2003,2005,2006 Jörg Sommer <joerg@alea.gnuu.de>
#    Copyright (C) 2008 Martin Kompf (skaringa at users.sourceforge.net)
#    Copyright (C) 2014, Erik Colson <ecocode@cpan.org>
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

# =============================================================

package Finance::Quote::VWD;
require 5.005;

use strict;
use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TreeBuilder;
use HTML::TableExtract;

# VERSION

sub methods { return ( vwd => \&vwd ); }

sub labels {
    return ( vwd => [ qw/currency date isodate name price last symbol time/ ] );
}

# =======================================================================
# The vwd routine gets quotes of funds from the website of
# vwd Vereinigte Wirtschaftsdienste GmbH.
#
# This subroutine was written by Volker Stuerzl <volker.stuerzl@gmx.de>
# and adjusted to match the new vwd interface by Jörg Sommer

# Trim leading and tailing whitespaces (also non-breakable whitespaces)
sub trim {
    $_ = shift();
    s/^\s*//;
    s/\s*$//;
    s/&nbsp;//g;
    return $_;
}

# Trim leading and tailing whitespaces, leading + and tailing %, leading
# and tailing &plusmn; (plus minus) and translate german separators into
# english separators. Also removes the thousands separator in returned
# values.
sub trimtr {
    $_ = shift();
    s/&nbsp;//g;
    s/&plusmn;//g;
    s/^\s*\+?//;
    s/\%?\s*$//;
    tr/,./.,/;
    s/,//g;
    return $_;
}

sub vwd {
    my $quoter = shift;
    my $ua     = $quoter->user_agent();
    my @funds  = @_;
    return unless (@funds);
    my %info;

    # LOGGING - set to 1 to enable log file
    my $logging = 0;
    if ($logging) {
        open( LOG, ">>/tmp/vwd.log" );
    }

    my $max_retry = 30;
    foreach my $fund (@funds) {
        $info{ $fund, "source" }   = "VWD";
        $info{ $fund, "success" }  = 0;
        $info{ $fund, "errormsg" } = "Parse error";

        my $request =
              "http://www.finanztreff.de/"
            . "kurse_einzelkurs_suche.htn?suchbegriff="
            . $fund;
        if ($logging) {
            print LOG "Request='$request'\n";
        }
        my $response = $ua->get($request);
        if ( $response->is_success ) {
            my $html = $response->decoded_content;

            my $tree = HTML::TreeBuilder->new;
            $tree->parse($html);

            # all other info below <div class=contentBox>
            my $content =
                $tree->look_down( "_tag", "div", "class", "contentBox" );
            next if not $content;

            my $wpkurs =
                $content->look_down( "_tag", "div", "class", qr/wpKurs/ );
            next if not $wpkurs;

            my $wpfacts =
                $content->look_down( "_tag", "div", "class", qr/wpFacts/ );
            next if not $wpfacts;

            my $title = $wpkurs->find("h1");
            $title->find("span")->delete_content;
            $info{ $fund, "name" } = $title->as_trimmed_text;

            my $te = HTML::TableExtract->new( depth => 0, count => 0 );
            $te->parse( $wpkurs->as_HTML );
            my $table = $te->first_table_found;

            # class val contains data. hopefully order and quantity won't change
            my @wpfacts_vals = $wpfacts->look_down( "_tag", "span","class", qr/val/);
            my $datum = $wpfacts_vals[1]->as_trimmed_text;

            if ($logging) {
                print LOG "datum: $datum\n";
            }
            if ( $datum =~ /([(0123]\d)\.([01]\d)\.(\d\d)/ ) {

                # datum contains date
                $quoter->store_date( \%info, $fund,
                                     { day => $1, month => $2, year => $3 } );
                $info{ $fund, "time" } = $quoter->isoTime("18:00");
            }
            elsif ( $datum =~ /([012]\d:[0-5]\d:[0-5]\d)/ ) {

                #datum contains time
                $quoter->store_date( \%info, $fund );
                $info{ $fund, "time" } = $quoter->isoTime($1);
            }
            my $kurs = $table->cell( 0, 1 );
            next if not $kurs;
            $info{ $fund, "price" } = $info{ $fund, "last" } = trimtr($kurs);

            # Currency (Währung)
            my $whrg =
                $tree->look_down( "_tag", "div", "class", "whrg" );
            if ($whrg) {
                my $whrgtext = $whrg->as_trimmed_text();
                $whrgtext =~ s/.*hrung: // ;
                $info{ $fund, "currency" } = $whrgtext;
            }
            else {
                $info{ $fund, "currency" } = "EUR";
            }

            my $symbol = $wpfacts_vals[4]->as_trimmed_text;
            $info{ $fund, "symbol" } = $symbol;

            # fund ok
            $info{ $fund, "success" }  = 1;
            $info{ $fund, "errormsg" } = "";

            # log
            if ($logging) {
                print LOG join( ':',
                                $info{ $fund, "name" },
                                $info{ $fund, "symbol" },
                                $info{ $fund, "date" },
                                $info{ $fund, "time" },
                                $info{ $fund, "price" },
                                $info{ $fund, "currency" } );
                print LOG "\n";
            }

            $tree->delete;
        }
        else {
            $info{ $fund, "success" }  = 0;
            $info{ $fund, "errormsg" } = "HTTP error " . $response->status_line;
            if ($logging) {
                print LOG "ERROR $fund: " . $info{ $fund, "errormsg" } . "\n";
            }
            if ( $response->code == 503 && $max_retry-- > 0 ) {

                # The server limits the number of request per time and client
                sleep 5;
                redo;
            }
        }
    }

    if ($logging) {
        close LOG;
    }
    return wantarray() ? %info : \%info;
}

1;

=head1 NAME

Finance::Quote::VWD  - Obtain quotes from vwd Vereinigte Wirtschaftsdienste GmbH.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %stockinfo = $q->fetch("vwd","847402");

=head1 DESCRIPTION

This module obtains information from vwd Vereinigte Wirtschaftsdienste GmbH
http://www.vwd.de/. Many european stocks and funds are available, but
at the moment only funds are supported.

Information returned by this module is governed by vwd's terms
and conditions.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::vwd:
currency date isodate name price last symbol time.

=head1 SEE ALSO

vwd Vereinigte Wirtschaftsdienste GmbH, http://www.vwd.de/

=cut
