#!/usr/bin/perl -w
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@cpan.org>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#    Copyright (C) 2001, Rob Sessink <rob_ses@users.sourceforge.net>
#    Copyright (C) 2003, Pawel Konieczny <konieczp@users.sourceforge.net>
#    Copyright (C) 2004, Johan van Oostrum
#    Copyright (C) 2009, Herman van Rink
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

require 5.005;

use strict;

package Finance::Quote::AEX;

use vars qw($VERSION $AEX_URL);

use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use HTML::TableExtract;
use CGI;

$VERSION = '1.19';

# URLs of where to obtain information

my $AEX_URL = "http://www.euronext.com/search/download/trapridownloadpopup.jcsv?pricesearchresults=actif&filter=1&belongsToList=market_EURLS&mep=8626&lan=NL&resultsTitle=Amsterdam+-+Euronext&cha=1800&format=txt&formatDecimal=.&formatDate=dd/MM/yy";

sub methods { return (dutch       => \&aex,
                      aex         => \&aex) }

{
  my @labels = qw/name symbol price last date time p_change bid ask offer open high low close volume currency method exchange/;

  sub labels { return (dutch       => \@labels,
                       aex         => \@labels) }
}

# ==============================================================================
########################################################################
# Stocks and indices

sub aex {
  my $quoter = shift;
  my @symbols = @_;
  return unless @symbols;

  my (%info,$url,$reply,$te);
  my ($row, $datarow, $matches);
  my ($time);

  $url = $AEX_URL;    		# base url

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

    # Open reply to read lins
    open FP, "<", \$reply->content or die "Unable to read data: $!";

    # Open temp file instead while debugging
    #open FP, "<", $filename or die "Unable to read data: $!";

    # Skip the first 4 lines, which are not CSV
    my $dummy = <FP>;	# Typical content: Stocks
    $dummy = <FP>;		# Typical content: Amsterdam - Euronext
    $dummy = <FP>;		# Typical content:
    $dummy = <FP>;		# Typical content: Instrument's name;ISIN;Euronext code;Market;Symbol;ICB Sector (Level 4);Handelsvaluta;Laatst;Aantal;D/D-1 (%);Datum-tijd (CET);Omzet;Totaal aantal aandelen;Capitalisation;Trading mode;Dag Open;Dag Hoog;Dag Hoog / Datum-tijd (CET);Dag Laag;Dag Laag / Datum-tijd (CET); 31-12/Change (%); 31-12/Hoog; 31-12/Hoog/Datum; 31-12/Laag; 31-12/Laag/Datum; 52 weken/Change (%); 52 weken/Hoog; 52 weken/Hoog/Datum; 52 weken/Laag; 52 weken/Laag/Datum;Suspended;Suspended / Datum-tijd (CET);Reserved;Reserved / Datum-tijd (CET)

    while (my $line = <FP>) {
      #print Dumper $line;
      my @row_data = $quoter->parse_csv_semicolon($line);
      #print Dumper \@row_data;
      my $row = \@row_data;
      #print Dumper $row;
      next unless @row_data;

      foreach my $symbol (@symbols) {

        my $found = 0;

        # Match Fund's name, ISIN or symbol
        if ( @$row[0] eq $symbol || @$row[1] eq $symbol || @$row[4] eq $symbol ) {
          $info {$symbol, "exchange"} = "Amsterdam Euronext eXchange";
          $info {$symbol, "method"} = "aex";
          $info {$symbol, "symbol"} = @$row[4];
          ($info {$symbol, "last"} = @$row[7]) =~ s/\s*//g;
          $info {$symbol, "bid"} = undef;
          $info {$symbol, "offer"} = undef;
          $info {$symbol, "low"} = @$row[18];
          $info {$symbol, "close"} = undef;
          $info {$symbol, "p_change"} = @$row[9];
          ($info {$symbol, "high"} = @$row[16]) =~ s/\s*//g;
          ($info {$symbol, "volume"} = @$row[8]) =~ s/\s*//g;

          # Split the date and time from one table entity
          my $dateTime = @$row[10];

          # Check for "dd mmm yyyy hh:mm" date/time format like "01 Aug 2004 16:34"
          if ($dateTime =~ m/(\d{2})\/(\d{2})\/(\d{2}) \s
                             (\d{2}:\d{2})/xi ) {
            $quoter->store_date(\%info, $symbol, {month => $2, day => $1, year => $3});
          }

          $info {$symbol, "currency"} = "EUR";
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

Finance::Quote::AEX Obtain quotes from Amsterdam Euronext eXchange

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("aex","AAB 93-08 7.5");  # Only query AEX
    %info = Finance::Quote->fetch("dutch","AAB 93-08 7.5"); # Failover to other sources OK

=head1 DESCRIPTION

This module fetches information from the "Amsterdam Euronext
eXchange AEX" http://www.aex.nl. Only local Dutch investment funds
and all traded here options and futures are available.

This module is loaded by default on a Finance::Quote object. It's
also possible to load it explicity by placing "AEX" in the argument
list to Finance::Quote->new().

Information obtained by this module may be covered by www.aex.nl
terms and conditions See http://www.aex.nl/ for details.

=head2 Stocks And Indices

This module provides both the "aex" and "dutch" fetch methods for fetching
stock and index quotes.  Please use the "dutch" fetch method if you wish
to have failover with future sources for Dutch stocks. Using the "aex"
method will guarantee that your information only comes from the Euronext
Amsterdam website.

Note that options and futures are not supported by this module.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::AEX :
name, last, date, p_change, bid, offer, open, high, low, close,
volume, currency, method, exchange, time.

=head1 SEE ALSO

Amsterdam Euronext eXchange, http://www.aex.nl

=cut
