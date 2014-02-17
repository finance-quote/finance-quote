#!/usr/bin/perl -w
#
# ZA.pm
#
# 2013.05.01
# Changes to table references to correct for new sharenet web page layout
# Timothy Boyle

# 2008.02.18
# This version corrects the data downloaded by removing spaces and converting
# cent values into Rand values – this ensures that the Price Editor in GNUCash
# can import the data. The rest of the module and all the hard work
# remains that of Stephen Langenhoven!
# Rolf Endres
#
# 2005.07.19
# Download of South African (ZA) stocks from sharenet
# This version based largely upon FinanceCanada.pm module [any errors
# are my own of course ;-) ]
# Stephen Langenhoven

package Finance::Quote::ZA;
require 5.004;

use strict;
use vars qw /$VERSION/;

use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;

$VERSION = '1.20' ;

my $SHARENET_MAINURL = ("http://www.sharenet.co.za/");
my $SHARENET_URL     = ( $SHARENET_MAINURL . "jse/" );

sub methods {
    return ( za => \&sharenet );
}

sub labels {
    my @labels =
        qw/method source name symbol currency last date isodate high low p_change/;
    return ( sharenet => \@labels );
}

sub sharenet {
    my $quoter  = shift;
    my @symbols = @_;
    my %info;
    my ( $te, $ts, $row );
    my @rows;

    return unless @symbols;

    my $ua = $quoter->user_agent;

    foreach my $symbol (@symbols) {
        my $url = $SHARENET_URL . $symbol;

        # print "[debug]: ", $url, "\n";
        my $response = $ua->request( GET $url);

        # print "[debug]: ", $response->content, "\n";

        if ( !$response->is_success ) {
            $info{ $symbol, "success" }  = 0;
            $info{ $symbol, "errormsg" } = "Error contacting URL";
            next;
        }

        $te = new HTML::TableExtract();
        $te->parse( $response->content );

        # print "[debug]: (parsed HTML)",$te, "\n";

        unless ( $te->first_table_found() ) {

            # print STDERR  "no tables on this page\n";
            $info{ $symbol, "success" }  = 0;
            $info{ $symbol, "errormsg" } = "Parse error";
            next;
        }

        # Debug to dump all tables in HTML...

        #   print "\n \n \n \n[debug]: ++++ ==== ++++ ==== ++++ ==== ++++ ==== START OF TABLE DUMP ++++ ==== ++++ ==== ++++ ==== ++++ ==== \n \n \n \n";
        #
        # foreach $ts ($te->table_states) {;
        #
        #   printf "\n \n \n \n[debug]: //// \\\\ //// \\\\ //// \\\\ //// \\\\ START OF TABLE %d,%d //// \\\\ //// \\\\ //// \\\\ //// \\\\ \n \n \n \n",
        #    $ts->depth, $ts->count;
        #
        #  foreach $row ($ts->rows) {
        #    print "[debug]: ", $row->[0], " | ", $row->[1], " | ", $row->[2], " | ", $row->[3], "\n";
        #   }
        # }
        #
        #   print "\n \n \n \n[debug]: ++++ ==== ++++ ==== ++++ ==== ++++ ==== END OF TABLE DUMP ++++ ==== ++++ ==== ++++ ==== ++++ ==== \n \n \n \n";

        # GENERAL FIELDS
        $info{ $symbol, "success" } = 1;
        $info{ $symbol, "method" }  = "sharenet";

        $info{ $symbol, "symbol" }   = $symbol;
        $info{ $symbol, "currency" } = "ZAR";
        $info{ $symbol, "source" }   = $SHARENET_MAINURL;

        # NAME
        $ts = $te->table_state( 2, 1 );    # new table reference
        if ($ts) {
            (@rows) = $ts->rows;
            $info{ $symbol, "name" } = $rows[2][1];
        }

        $info{ $symbol, "name" } =~ tr/ //d;

        # DATE AND CLOSING PRICE
        $ts = $te->table_state( 3, 0 );   # change table for new sharenet layout

        # print "[debug]: ", "got this far...", "\n";
        # print "[debug]: (table_state)",$ts, "\n";
        if ($ts) {
            (@rows) = $ts->rows;

            # date for last trade sale, high, low
            # sharenet only gives the day and month. We could use today's date, but this would not
            # be correct over weekends and public holidays (if it matters)
            my $date =
                substr( $rows[0][0], 16, 5 )
                . "/";    #extract the day/month from the string and add /

            # this does the same as above in a more robust fashion
            #     my $date  = $rows[0][0]; # day/month plus time plus text
            #     $date =~ s/[^0-9\/]//g; # remove most unwanted characters
            #     $date =~ s/\d{4}$/\//; # remove last 4 digits = time and add / for the year

            my $year =
                ( localtime() )[5]
                + 1900;    # extract year from system time vector
            $date = $date . $year;    # add it to the day/month

            # print $date, "\n"; # we now have the date of the trades as dd/mm/yyyy
            $quoter->store_date( \%info, $symbol, { eurodate => $date } )
                ;                     # gives eurodate and isodate symbols

            # $quoter->store_date(\%info, $symbol, {today => 1}); # could use today's date
            # last traded price
            $info{ $symbol, "last" } = $rows[2][1];
            $info{ $symbol, "last" } =~ tr/ //d;
            $info{ $symbol, "last" } = 0.01 * $info{ $symbol, "last" };

            # highest price today
            $info{ $symbol, "high" } = $rows[16][1];
            $info{ $symbol, "high" } =~ tr/ //d;
            $info{ $symbol, "high" } = 0.01 * $info{ $symbol, "high" };

            # lowest price today
            $info{ $symbol, "low" } = $rows[18][1];
            $info{ $symbol, "low" } =~ tr/ //d;
            $info{ $symbol, "low" } = 0.01 * $info{ $symbol, "low" };

            # percent change from previous close
            $info{ $symbol, "p_change" } = $rows[10][1];
            $info{ $symbol, "p_change" } =~ tr/ //d;

            # actual net change from previous close
            $info{ $symbol, "net" } = $rows[8][1];
            $info{ $symbol, "net" } =~ tr/ //d;

        }

    }

    return wantarray() ? %info : \%info;
}

1;

=head1 NAME

Finance::Quote::ZA - Obtain South African stock and prices from
www.sharenet.co.za

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    # Don't know anything about failover yet...

=head1 DESCRIPTION

This module obtains information about South African Stocks from
www.sharenet.co.za.

=head1 LABELS RETURNED

Information available from sharenet may include the following labels:

method source name symbol currency date nav last price

=head1 SEE ALSO

Sharenet website - http://www.sharenet.co.za/

Finance::Quote

=cut
