#!/usr/bin/perl -w
#
#    Copyright (C) 2004, Michael Curtis 
#    Modified from DWS.pm - its copyrights
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@Acpan.org>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#    Copyright (C) 2000, Volker Stuerzl <volker.stuerzl@gmx.de>
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
#

package Finance::Quote::NZX;
require 5.005;

use strict;
use LWP::UserAgent;
use HTTP::Request::Common;

use vars qw/$VERSION/; 

$VERSION = '1.00';

sub methods { return (nz => \&nzx, nzx => \&nzx); }
sub labels {
	my @labels = qw/exchange name price last date isodate method/;

	return (nz => \@labels, nzx => \@labels);
}



sub nzx
{
  my $nzxurl = "http://www.nzx.com/scripts/portal_pages/p_csv_by_market.csv?code=ALL&board_type=S";
  my $quoter = shift;
  my @symbols = @_;
  return unless @symbols;
  my $isLineOne = 1;
  my $ua = $quoter->user_agent;
  my $sDate;
  my (%symbolhash, @q, %info);

  # create hash of all stocks requested
  foreach my $symbol (@symbols)
  {
    $symbolhash{$symbol} = 0;
  }

  # get csv data
  my $response = $ua->request(GET $nzxurl);
  if ($response->is_success)
  {
    # process csv data
    foreach (split('\015?\012',$response->content))
    {
      if ($isLineOne == 1)
      {
       $isLineOne = 0;
       ($sDate) =  ($_ =~ /([0-9]{4}\/[0-9]{2}\/[0-9]{2})/g);
      }
      @q = $quoter->parse_csv($_) or next;
      if (exists $symbolhash{$q[0]})
      {
        $symbolhash{$q[0]} = 1;

        $info{$q[0], "exchange"} = "NZX";
        $info{$q[0], "name"}     = $q[0];
        $info{$q[0], "symbol"}   = $q[0];
        $info{$q[0], "price"}    = $q[1];
        $info{$q[0], "last"}     = $q[7];
	$quoter->store_date(\%info, $q[0], {isodate => $sDate});
        $info{$q[0], "method"}   = "nzx";
        $info{$q[0], "currency"} = "NZD";
        $info{$q[0], "success"}  = 1;
      }
    }

    # check to make sure a value was returned for every stock requested
    foreach my $symbol (keys %symbolhash)
    {
      if ($symbolhash{$symbol} == 0)
      {
        $info{$symbol, "success"}  = 0;
        $info{$symbol, "errormsg"} = "No data returned";
      }
    }
  }
  else
  {
    foreach my $symbol (@symbols)
    {
      $info{$symbol, "success"}  = 0;
      $info{$symbol, "errormsg"} = "HTTP error";
    }
  }

  return wantarray() ? %info : \%info;
}


1;

=head1 NAME

Finance::Quote::NZX	- Obtain quotes from NZX (New Zealand stock exchange.)

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %stockinfo = $q->fetch("nzx","TPW");

=head1 DESCRIPTION

This module obtains information about NZX companies.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::NZX:
exchange, name, date, price, last.

=head1 SEE ALSO

NZX (New Zealand stock exchange), http://www.nzx.com/

=cut
