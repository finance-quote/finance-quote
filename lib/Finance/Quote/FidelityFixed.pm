#!/usr/bin/perl -w
#
# FidelityFixed.pm
#

# Version 1.01
# Modification of Rolf Endres' Finance::Quote::ZA
#
# Peter Ratzlaff <pratzlaff@gmail.com>
# 2012.01.04

package Finance::Quote::FidelityFixed;
require 5.004;

use strict;
use vars qw /$VERSION/ ;

use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;

$VERSION = '1.01';

# e.g., http://fixedincome.fidelity.com/fi/FIIndividualBondsSearch?cusip=912810QT8
# This URL should really be "https://fixedincome.fidelity.com/", but that host name
# maps to a number of different servers, some of which work with the Perl code and
# some of which don't.  So instead we pick one that we know works as of 6/3/2013.
# This might change, in which case we'll have to find another one that works.  One
# way to do that is to try fixedincome.fidelity.com repeadedly while watching with
# WireShark until you find one that works.
my $FIDELITY_MAINURL = ("https://fixedincome6800rtp.fidelity.com/");
my $FIDELITY_URL = ($FIDELITY_MAINURL."ftgw/fi/FIIndividualBondsSearch?cusip=");

sub methods {
    return (fidelityfixed => \&fidelityfixed);
}


sub labels {
    my @labels = qw/ method source name symbol coupon bid bidyield askyield ask date isodate time price /;
    return (fidelityfixed => \@labels);
}   


sub fidelityfixed {

    my $quoter = shift;
    my @symbols = @_;
    my %info;
    my ($te, $ts, $row);
    my @rows;

    return unless @symbols;

    my $ua = $quoter->user_agent;
    $ua->ssl_opts(verify_hostname => 0);

    foreach my $symbol (@symbols) {
        my $url = $FIDELITY_URL.$symbol;
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

=begin comment

           print "\n \n \n \n[debug]: ++++ ==== ++++ ==== ++++ ==== ++++ ==== START OF TABLE DUMP ++++ ==== ++++ ==== ++++ ==== ++++ ==== \n \n \n \n";

         foreach $ts ($te->table_states) {;

           printf "\n \n \n \n[debug]: //// \\\\ //// \\\\ //// \\\\ //// \\\\ START OF TABLE %d,%d //// \\\\ //// \\\\ //// \\\\ //// \\\\ \n \n \n \n",
	     $ts->depth, $ts->count;

           foreach $row ($ts->rows) {
             print '[debug]: ', join('|', @$row), "\n";
           }
         }

           print "\n \n \n \n[debug]: ++++ ==== ++++ ==== ++++ ==== ++++ ==== END OF TABLE DUMP ++++ ==== ++++ ==== ++++ ==== ++++ ==== \n \n \n \n";

=cut


# GENERAL FIELDS
        $info{$symbol, "method"} = "fidelityfixed";
        $info{$symbol, "symbol"} = $symbol;
        $info{$symbol, "source"} = $FIDELITY_MAINURL;

# OTHER INFORMATION
        $ts = $te->table_state(0,1);
        if($ts) {
          (@rows) = $ts->rows;
          my $n = 3;
          if ($rows[$n][1] =~ /Fidelity is not currently offering this security/) {
              $n = 4;
          }
          if (
              $rows[$n][1] !~ /do not match/ and
              $rows[$n][1] !~ /return to the previous page/ and
              1
	      )
	  {
	      $info{$symbol, 'success'} = 1;
	      $info{$symbol, 'name'}     = $rows[$n][1];
	      $info{$symbol, 'coupon'}   = $rows[$n][2];
	      $info{$symbol, 'maturity'} = $rows[$n][3];
	      $info{$symbol, 'bidyield'} = $rows[$n][6];
	      $info{$symbol, 'bid'}      = $rows[$n][7];
	      $info{$symbol, 'ask'}      = $rows[$n][8];
	      $info{$symbol, 'askyield'} = $rows[$n][9];
	      $info{$symbol, 'recent'}   = $rows[$n][11];

	      ($_) = /(\d+\.\d+)/ for $info{$symbol, 'bid'}, $info{$symbol, 'ask'}, $info{$symbol, 'recent'};
	      $info{$symbol, 'price'} = sprintf("%.2f", 0.5*($info{$symbol,'bid'} + $info{$symbol,'ask'}));
	      if ($info{$symbol, 'bid'} == 0 || $info{$symbol, 'ask'} == 0) {
	          $info{$symbol, 'price'} = $info{$symbol, 'recent'};
	      }
	      $info{$symbol, 'currency'} = 'USD';

	      # clean things up a bit
	      $info{$symbol, 'name'} =~ s/^\s+//;
	      $info{$symbol, 'name'} =~ s/\s+$//;
	      ($_) = /(\d+\.\d+)/ for $info{$symbol, 'price'};

	      if ($response->content =~ /As of (\d+)\/(\d+)\/(\d+) at (\d+)\:(\d+) ([ap])\.m\./) {
		  $info{$symbol, 'date'} = "$1/$2/$3";
		  $info{$symbol, 'isodate'} = "$3-$2-$1";
		  $info{$symbol, 'time'} = $6 eq 'a' ? "$4:$5" : ($4+12).":$5";
	      }
          }

          else { $info{$symbol, "errormsg"} = "no match"; }
        };


    }

    return wantarray() ? %info : \%info;
}

1;

=head1 NAME

Finance::Quote::FidelityFixed- Obtain individual bond quotes from Fidelity

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    # Don't know anything about failover yet...

=head1 DESCRIPTION

This module obtains individual bond quotes by CUSIP from fixedincome.fidelity.com

=head1 LABELS RETURNED

Information available from FidelityFixed may include the following labels:

method source name symbol coupon bid bidyield askyield ask date isodate time price

=head1 SEE ALSO

fidelity.com

Finance::Quote

=cut
