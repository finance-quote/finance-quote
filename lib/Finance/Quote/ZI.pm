#!/usr/bin/perl -w
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@Acpan.org>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#    Copyright (C) 2000, Volker Stuerzl <volker.stuerzl@gmx.de>
#    Copyright (C) 2002, Rainer Dorsch <rainer.dorsch@informatik.uni-stuttgart.de>
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
# This code derived from Voler Stuerzl's work on package Finace::Quote::DWS,
# but extends its capabilites to encompas a greater number of data sources.
#
# $Id: ZI.pm,v 1.2 2005/03/20 01:44:13 hampton Exp $

package Finance::Quote::ZI;
require 5.005;

use strict;
use LWP::UserAgent;
use HTTP::Request::Common;

use vars qw/$VERSION/;

$VERSION = '1.00';

sub methods { return (zifunds => \&zifunds); }
sub labels { return (zifunds => [qw/exchange name date isodate price method/]); }

# =======================================================================
# The zifunds routine gets quotes of ZI funds (Zurich Financial Services Group)
# On their website ZI provides a csv file in the format
#    label1,label2,...
#    date1,name1,currency1,buy1,bid1,change to previous day1,symbol1,...
#    date2,name2,currency2,buy2,bid2,change to previous day2,symbol2,...
#    ...
#
# This subroutine was written by Volker Stuerzl <volker.stuerzl@gmx.de>

sub zifunds
{
  my $quoter = shift;
  my @funds = @_;
  return unless @funds;
  my $ua = $quoter->user_agent;
  my (%fundhash, @q, @date, %info);

  # create hash of all funds requested
  foreach my $fund (@funds)
  {
    $fundhash{$fund} = 0;
  }

  # get csv data
  my $response = $ua->request(GET &ziurl);
  if ($response->is_success)
  {
    # process csv data
    foreach (split('\015?\012',$response->content))
    {
#      @q = $quoter->parse_csv($_) or next;
      @q = split(/;/) or next;
      if (exists $fundhash{$q[6]})
      {
        $fundhash{$q[6]} = 1;

        # convert price from german (0,00) to US format (0.00)
        $q[4] =~ s/,/\./;

        $info{$q[6], "exchange"} = "ZI";
        $info{$q[6], "name"}     = $q[6];
        $info{$q[6], "symbol"}   = $q[6];
        $info{$q[6], "price"}    = $q[4];
        $info{$q[6], "last"}     = $q[4];
	$quoter->store_date(\%info, $q[6], {eurodate => $q[0]});
        $info{$q[6], "method"}   = "zifunds";
        $info{$q[6], "currency"} = $q[2];
        $info{$q[6], "success"}  = 1;
      }
    }

    # check to make sure a value was returned for every fund requested
    foreach my $fund (keys %fundhash)
    {
      if ($fundhash{$fund} == 0)
      {
        $info{$fund, "success"}  = 0;
        $info{$fund, "errormsg"} = "No data returned";
      }
    }
  }
  else
  {
    foreach my $fund (@funds)
    {
      $info{$fund, "success"}  = 0;
      $info{$fund, "errormsg"} = "HTTP error";
    }
  }

  return wantarray() ? %info : \%info;
}

# ZI provides a csv file named preise.csv containing the prices of all
# their funds for the most recent business day.

sub ziurl
{
  return "http://www.zuerich-invest.de/preise.csv";
}

1;

=head1 NAME

Finance::Quote::ZI	- Obtain quotes from ZI (Zurich Financial Services Group).

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %stockinfo = $q->fetch("zifunds","847402");

=head1 DESCRIPTION

This module obtains information about ZI managed funds.

Information returned by this module is governed by ZI's terms
and conditions.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::ZI:
exchange, name, date, price, last.

=head1 SEE ALSO

ZI (Zuerich Invest), http://www.zuerich-invest.de/

=cut




