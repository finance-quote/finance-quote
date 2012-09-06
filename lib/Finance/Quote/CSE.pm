#!/usr/bin/perl -w
#
#    This modules is based on the AEX module. The code has been modified by 
#    Hiranya Samarasekera <hiranyas@gmail.com> to be able to retrieve stock
#    information from the Colombo Stock Exchange (CSE) in Sri Lanka.
#    ----------------------------------------------------------------------
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

require 5.005;

use strict;

package Finance::Quote::CSE;

use vars qw($VERSION $CSE_URL);

use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use HTML::TableExtract;
use CGI;

$VERSION = '1.17';

my $CSE_URL = "http://www.cse.lk/trade_summary_report.do?reportType=CSV";

sub methods { return (cse       => \&cse) }

{
  my @labels = qw/ID SYMBOL NAME LAST_TRADE_QUANTITY TRADE_DATE PRICE SHAREVOLUME TRADEVOLUME TURNOVER HI_TRADE LO_TRADE CHANGE CHANGE_PERCENTAGE ISSUE_DATE CLOSING_PRICE PREVIOUS_CLOSE MARKET_CAP MARKET_CAP_PERCENTAGE OPEN currency method exchange/;

  sub labels { return (cse       => \@labels) }
}

# Colombo Stock Exchange (CSE), Sri Lanka

sub cse {
  my $quoter = shift;
  my @symbols = @_;
  return unless @symbols;

  my (%info,$url,$reply,$te);
  my ($row, $datarow, $matches);
  my ($time);

  $url = $CSE_URL;    		# base url 

  # Create a user agent object and HTTP headers
  my $ua  = new LWP::UserAgent(agent => 'Mozilla/4.0 (compatible; MSIE 5.5; Windows 98)');

  # Compose POST request
  my $request = new HTTP::Request("GET", $url);

  $reply = $ua->request( $request );

  #print Dumper $reply;
  if ($reply->is_success) { 

    # Write retreived data to temp file for debugging
    use POSIX;
    my $filename = tmpnam();
    open my $fw, ">", $filename or die "$filename: $!";
    print $fw $reply->content;
    close $fw;

    # Open reply to read lines
    open FP, "<", \$reply->content or die "Unable to read data: $!";

    # Open temp file instead while debugging
    #open FP, "<", $filename or die "Unable to read data: $!";

    while (my $line = <FP>) {
      my @row_data = $quoter->parse_csv($line);
      #print Dumper \@row_data;
      my $row = \@row_data;
      #print Dumper $row;
      next unless @row_data;

      foreach my $symbol (@symbols) {

        my $found = 0;

        # Match stock symbol (e.g. JKH.N0000, HNB.X0000)
        if ( @$row[1] eq uc($symbol) ) {
          $info {$symbol, "exchange"} = "Colombo Stock Exchange, Sri Lanka";
          $info {$symbol, "method"} = "cse";
          $info {$symbol, "symbol"} = @$row[1];
          $info {$symbol, "name"} = @$row[2];
          ($info {$symbol, "last"} = @$row[5]) =~ s/\s*//g;
          $info {$symbol, "bid"} = undef;
          $info {$symbol, "offer"} = undef;
          $info {$symbol, "open"} = @$row[18];
          $info {$symbol, "nav"} = undef;
          $info {$symbol, "price"} = @$row[5];
          $info {$symbol, "low"} = @$row[10];
          $info {$symbol, "close"} = @$row[15];
          $info {$symbol, "p_change"} = @$row[12];
          ($info {$symbol, "high"} = @$row[9]) =~ s/\s*//g;
          ($info {$symbol, "volume"} = @$row[6]) =~ s/,//g;;

          $quoter->store_date(\%info, $symbol, {today => 1});

          $info {$symbol, "currency"} = "LKR";
          $info {$symbol, "success"} = 1; 
        }
      }
    }
  }

  foreach my $symbol (@symbols) {
    unless ( !defined($info {$symbol, "success"}) || $info {$symbol, "success"} == 1 ) 
      {
        $info {$symbol,"success"} = 0;
        $info {$symbol,"errormsg"} = "Fund name $symbol not found";
        next;
      }
  }

  #print Dumper \%info;
  return %info if wantarray;
  return \%info;
}


1; 

=head1 NAME

Finance::Quote::CSE Obtain quotes from Colombo Stock Exchange in Sri Lanka

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;
	@stocks = ("JKH.N0000", "HPWR.N0000", "HNB.X0000");
    %info = Finance::Quote->fetch("cse", @stocks); 

=head1 DESCRIPTION

This module retrieves information from the Colombo Stock Exchange (CSE)
in Sri Lanka http://www.cse.lk.

This module is loaded by default on a Finance::Quote object. It's 
also possible to load it explicity by placing "cse" in the argument
list to Finance::Quote->new().

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::CSE :
symbol, name, last, open, price, low, close, p_change,
high, volume, exchange, method

=head1 SEE ALSO

Colombo Stock Exchange (CSE), Sri Lanka, http://www.cse.lk

=cut

