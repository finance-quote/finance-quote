#!/usr/bin/perl -w
#
# ZA.pm
#
# Version 0.1 - Download of South African (ZA) stocks from sharenet
# This version based largely upon FinanceCanada.pm module [any errors
# are my own of course ;-) ]
#
# Stephen Langenhoven
# 2005.07.19


package Finance::Quote::ZA;
require 5.004;

use strict;

use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;

my $SHARENET_MAINURL = ("http://www.sharenet.co.za/");
my $SHARENET_URL = ($SHARENET_MAINURL."jse/");

sub methods {
    return (za => \&sharenet);
}


sub labels {
    my @labels = qw/method source name symbol currency last date isodate high low p_change/;
    return (sharenet => \@labels);
}   


sub sharenet {

    my $quoter = shift;
    my @symbols = @_;
    my %info;
    my ($te, $ts, $row);
    my @rows;

    return unless @symbols;

    my $ua = $quoter->user_agent;

    foreach my $symbol (@symbols) {
        my $url = $SHARENET_URL.$symbol;
        #print "[debug]: ", $url, "\n";
        my $response = $ua->request(GET $url);
        #print "[debug]: ", $response->content, "\n";

        if (!$response->is_success) {
            $info{$symbol, "success"} = 0;
            $info{$symbol, "errormsg"} = "Error contacting URL";
            next;
        }

        $te = new HTML::TableExtract();
        $te->parse($response->content);
        #print "[debug]: (parsed HTML)",$te, "\n";

	unless ($te->first_table_found()) {
	  #print STDERR  "no tables on this page\n";
	  $info{$symbol, "success"}  = 0;
	  $info{$symbol, "errormsg"} = "Parse error";
	  next;
	}

# Debug to dump all tables in HTML...

#           print "\n \n \n \n[debug]: ++++ ==== ++++ ==== ++++ ==== ++++ ==== START OF TABLE DUMP ++++ ==== ++++ ==== ++++ ==== ++++ ==== \n \n \n \n";
#
#         foreach $ts ($te->table_states) {;
#
#           printf "\n \n \n \n[debug]: //// \\\\ //// \\\\ //// \\\\ //// \\\\ START OF TABLE %d,%d //// \\\\ //// \\\\ //// \\\\ //// \\\\ \n \n \n \n",
#	     $ts->depth, $ts->count;
#
#           foreach $row ($ts->rows) {
#             print "[debug]: ", $row->[0], " | ", $row->[1], " | ", $row->[2], " | ", $row->[3], "\n";
#           }
#         }
#
#           print "\n \n \n \n[debug]: ++++ ==== ++++ ==== ++++ ==== ++++ ==== END OF TABLE DUMP ++++ ==== ++++ ==== ++++ ==== ++++ ==== \n \n \n \n";


# GENERAL FIELDS
	$info{$symbol, "success"} = 1;
        $info{$symbol, "method"} = "sharenet";

        $info{$symbol, "symbol"} = $symbol;
        $info{$symbol, "currency"} = "ZAR";
        $info{$symbol, "source"} = $SHARENET_MAINURL;

# NAME
        $ts = $te->table_state(2,1);
        if($ts) {
          (@rows) = $ts->rows;
          $info{$symbol, "name"} = $rows[2][1];
        }

# DATE AND CLOSING PRICE
        $ts = $te->table_state(3,1);
#         print "[debug]: ", "got this far...", "\n";
#         print "[debug]: (table_state)",$ts, "\n";
        if($ts) {
          (@rows) = $ts->rows;

#           foreach $row ($ts->rows) {
#             print "[debug]: ", $row->[0], " | ", $row->[1], " | ", $row->[2], " | ", $row->[3], "\n";
#           }

	  $quoter->store_date(\%info, $symbol, {eurodate => $rows[0][0]});
          $info{$symbol, "last"}  = $rows[1][1];
          $info{$symbol, "high"}  = $rows[2][1];
          $info{$symbol, "low"}   = $rows[3][1];
	  $info{$symbol, "p_change"} = $rows[6][1];

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

