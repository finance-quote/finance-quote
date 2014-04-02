#!/usr/bin/perl -w

# This file is based purely on Stephen Langenhoven's original ZA.pm file.
# In order to use this file, rather than using a stock code/number, the user
# must look for the unit trust ID number in the path of the Equinox site that
# profiles the relevant unit trust (or closest unit trust to). For instance,
# http://www.equinox.co.za/unittrusts/funds/funddetails.asp?fundid=16200 is the
# profile of the "Liberty Resources Fund (C)". As a result, the fundid to be used
# to query that fund is 16200.
# Rolf Endres
# 2009.10.09

package Finance::Quote::za_unittrusts;
require 5.004;

use strict;

use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;

my $EQUINOX_MAINURL = ("http://www.equinox.co.za/");
my $EQUINOX_URL =
    ( $EQUINOX_MAINURL . "unittrusts/funds/funddetails.asp?fundid=" );

sub methods {
    return ( za_unittrusts => \&za_unittrusts );
}

sub labels {
    my @labels =
        qw/method source name symbol currency last date isodate high low p_change/;
    return ( EQUINOX => \@labels );
}

sub za_unittrusts {

    my $quoter  = shift;
    my @symbols = @_;
    my %info;
    my ( $te, $ts, $row );
    my @rows;

    return unless @symbols;

    my $ua = $quoter->user_agent;

    foreach my $symbol (@symbols) {
        my $url = $EQUINOX_URL . $symbol;

        #print "[debug]: ", $url, "\n";
        my $response = $ua->request( GET $url);

        #print "[debug]: ", $response->content, "\n";

        if ( !$response->is_success ) {
            $info{ $symbol, "success" }  = 0;
            $info{ $symbol, "errormsg" } = "Error contacting URL";
            next;
        }

        $te = new HTML::TableExtract();

        $te->parse( $response->content );

        #print "[debug]: (parsed HTML)",$te, "\n";

        unless ( $te->first_table_found() ) {

            #print STDERR  "no tables on this page\n";
            $info{ $symbol, "success" }  = 0;
            $info{ $symbol, "errormsg" } = "Parse error";
            next;
        }

        # GENERAL FIELDS
        $info{ $symbol, "success" }  = 1;
        $info{ $symbol, "method" }   = "Equinox";
        $info{ $symbol, "symbol" }   = $symbol;
        $info{ $symbol, "currency" } = "ZAR";
        $info{ $symbol, "source" }   = $EQUINOX_MAINURL;

        # NAME
        $ts = $te->table_state( 0, 0 );
        if ($ts) {
            (@rows) = $ts->rows;
            $info{ $symbol, "name" } = $rows[0][0];
            $info{ $symbol, "name" } =~ s/Funds//;
            $info{ $symbol, "name" } =~ s/Performances//;
            $info{ $symbol, "name" } =~ s/Companies//;
            $info{ $symbol, "name" } =~ s/Summary//;
            $info{ $symbol, "name" } =~ s/Company//;
            $info{ $symbol, "name" } =~ s/Management//;
            $info{ $symbol, "name" } =~ s/A//;
            $info{ $symbol, "name" } =~ s/Z//;
            $info{ $symbol, "name" } =~ s/Risk//;
            $info{ $symbol, "name" } =~ s/Funds//;
            $info{ $symbol, "name" } =~ s/Sector//;
            $info{ $symbol, "name" } =~ s/Funds//;
            $info{ $symbol, "name" } =~ s/Domestic(.*)//s;
            $info{ $symbol, "name" } =~ s/Foreign(.*)//s;
            $info{ $symbol, "name" } =~ s/[^A-Za-z ()]//sg;
            $info{ $symbol, "name" } =~ s/  //sg;
            $info{ $symbol, "name" } =~ s/  //sg;
            $info{ $symbol, "name" } =~ s/  //sg;
            $info{ $symbol, "name" } =~ s/  //sg;

        }

        # LAST
        $ts = $te->table_state( 1, 0 );
        if ($ts) {
            (@rows) = $ts->rows;
            $info{ $symbol, "last" } = $rows[0][1];
            $info{ $symbol, "last" } =~ tr/R //d;

        }

        # DATE
        if ($ts) {
            (@rows) = $ts->rows;

            $quoter->store_date( \%info, $symbol, { eurodate => $rows[0][0] } );
        }
    }

    return wantarray() ? %info : \%info;
}

1;

=head1 NAME

Finance::Quote::za_unittrusts - Obtain South African unit trust prices from
www.equinox.co.za

=head1 SYNOPSIS

   use Finance::Quote;

   $q = Finance::Quote->new;

   # Don't know anything about failover yet...

=head1 DESCRIPTION

This module obtains information about South African Unit Trusts from
www.equinox.co.za.

=head1 LABELS RETURNED

Information available from Equinox may include the following labels:

method source name symbol currency date nav last price

=head1 SEE ALSO

Equinox website - http://www.equinox.co.za/

Finance::Quote

=cut
