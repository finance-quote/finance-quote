#!/usr/bin/perl -W
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@Acpan.org>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#    Copyright (C) 2000, Volker Stuerzl <volker.stuerzl@gmx.de>
#    Copyright (C) 2003,2005,2006 Jörg Sommer <joerg@alea.gnuu.de>
#    Copyright (C) 2008 Martin Kompf (skaringa at users.sourceforge.net)
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

# use vars qw/$VERSION $VWD_FUNDS_URL/;

use vars qw/$VERSION/;

$VERSION = '1.13_01';

sub methods { return (vwd => \&vwd); }
sub labels { return (vwd => [qw/currency date isodate 
            name price last symbol time/]); }

# =======================================================================
# The vwd routine gets quotes of funds from the website of
# vwd Vereinigte Wirtschaftsdienste GmbH.
#
# This subroutine was written by Volker Stuerzl <volker.stuerzl@gmx.de>
# and adjusted to match the new vwd interface by Jörg Sommer

# Trim leading and tailing whitespaces (also non-breakable whitespaces)
sub trim
{
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
sub trimtr
{
    $_ = shift();
    s/&nbsp;//g;
    s/&plusmn;//g;
    s/^\s*\+?//;
    s/\%?\s*$//;
    tr/,./.,/;
    s/,//g;
    return $_;
}

sub vwd
{
  my $quoter = shift;
  my $ua = $quoter->user_agent();
  my @funds = @_;
  return unless (@funds);
  my %info;

  foreach my $fund (@funds)
  {
    $info{$fund, "source"} = "VWD";
    $info{$fund, "success"} = 0;
    $info{$fund, "errormsg"} = "Parse error";

    my $response = $ua->get("http://www.finanztreff.de/".
   "kurse_einzelkurs_uebersicht.htn?s=".$fund);
    if ($response->is_success)
    {
      my $html = $response->content;

      my $tree = HTML::TreeBuilder->new;
      $tree->parse($html);

      # date from the top of the page
      my $date_time = $tree->look_down(
         "_tag", "span",
         "class", "time");
      next if not $date_time;
      if ($date_time->as_text =~ /(\d\d)\.(\d\d)\. \d\d:\d\d/) {
         $quoter->store_date(\%info, $fund, {day => $1, month => $2});
      }

      # all other info below <div class=contentContainer>
      my $content = $tree->look_down(
         "_tag", "div",
         "class", "contentContainer"
      );
      next if not $content;

      # <h1> contains price, time, name, and symbol
      my $head = $content->find("h1");
      next if not $head;

      my $wpkurs = $head->look_down(
         "_tag", "div",
         "class", "wpKurs"
      );
      next if not $wpkurs;
      my $time = $wpkurs->look_down(
         "_tag", "div",
         "class", "datum"
      );
      if ($time) {
         $info{$fund, "time"} = $time->as_trimmed_text;
      }
      my $kurs = $wpkurs->look_down(
         "_tag", "div",
         "class", "kurs");
      next if not $kurs;
      $info{$fund, "price"} = $info{$fund, "last"} = trimtr($kurs->as_text);

      foreach ($head->descendants) {
         $_->delete;
      }

      if ($head->as_trimmed_text =~ /^(.*) \((.+)\)$/) {
         $info{$fund, "name"} = $1;
         $info{$fund, "symbol"} = $2;
      }

      # <ul> contains currency as 3rd <li>
      my $wpinfo = $content->look_down(
         "_tag", "ul",
         "class", "wpInfo"
      );
      if ($wpinfo) {
         my @li = $wpinfo->find("li");
         if ($li[2]->as_text =~ /Währung:(\w+)/) {
            $info{$fund, "currency"} = substr($1, 0, 3);
         }
      }

      # fund ok
      $info{$fund, "success"}  = 1;
      $info{$fund, "errormsg"} = "";

      $tree->delete;
    } else {
      $info{$fund, "success"}  = 0;
      $info{$fund, "errormsg"} = "HTTP error";
    }
  }

  return wantarray() ? %info : \%info;
}

1;

=head1 NAME

Finance::Quote::vwd  - Obtain quotes from vwd Vereinigte Wirtschaftsdienste GmbH.

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

 	  	 
