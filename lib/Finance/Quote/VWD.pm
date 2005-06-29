#!/usr/bin/perl -w
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@Acpan.org>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#    Copyright (C) 2000, Volker Stuerzl <volker.stuerzl@gmx.de>
#    Copyright (C) 2003,2005 J�rg Sommer <joerg@alea.gnuu.de>
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

use HTML::TableExtract;
@ISA = qw( HTML::TableExtract );

sub start {
  # Fool ourselves into translating <br> to "\n"
  my $self = shift;
  $self->text("\n") if $_[0] eq 'br';
  $self->SUPER::start(@_);
}
# =============================================================

package Finance::Quote::VWD;
require 5.005;

use strict;
use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;

# use vars qw/$VERSION $VWD_FUNDS_URL/;

# $VERSION = '1.00';

sub methods { return (vwd => \&vwd); }
sub labels { return (vwd => [qw/ask bid currency date isodate exchange last
				name net p_change price symbol time year_range/]); }

# =======================================================================
# The vwd routine gets quotes of funds from the website of
# vwd Vereinigte Wirtschaftsdienste GmbH.
#
# This subroutine was written by Volker Stuerzl <volker.stuerzl@gmx.de>
# and adjusted to match the new vwd interface by J�rg Sommer

# Trim leading and tailing whitespaces (also non-breakable whitespaces)
sub trim
{
    $_ = shift();
    s/^\s*//;
    s/\s*$//;
    s/&nbsp;//g;
    return $_;
}

# Trim leading and tailing whitespaces, leading + and tailing % and
# translate german separators into english separators
sub trimtr
{
    $_ = shift();
    s/&nbsp;//g;
    s/^\s*\+?//;
    s/\%?\s*$//;
    tr/,./.,/;
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
    
    my $response = $ua->get("http://www.finanztreff.de/ftreff/".
	"kurse_einzelkurs_uebersicht.htm?s=".$fund);
    if ($response->is_success)
    {
      # Sometimes a table is before our tables, but we must use absolute
      # addressing, because colspan in table head hides columns in all rows
      my $table = new HTML::TableExtract
	  (decode=>0, headers=>["Stammdaten"])->parse($response->content);
      unless ($table->first_table_state_found()) {
	print "table doesn't exist 2\n";
	$info{$fund, "success"}  = 0;
	$info{$fund, "errormsg"} = "Parse error";
	next;
      }
      my $tabOffset = $table->first_table_state_found()->count() - 2;

      # parse table "Stammdaten" and extract its contents
      my @rows = new HTML::TableExtract
	  (decode=>0, depth=>2, count=>2+$tabOffset)->parse($response->content)->rows();

      next unless (@rows);
      $info{$fund, "symbol"}   = trim( $rows[4][1] );
      $info{$fund, "name"}     = trim( $rows[1][1] );
      $info{$fund, "currency"} = trim( $rows[8][1] );
	
      # parse table "Jahreschart" and extract its contents
      @rows = new HTML::TableExtract
	  (depth => 2, count => 3+$tabOffset)->parse($response->content)->rows();

      next unless (@rows);
      $quoter->store_date(\%info, $fund, {eurodate => $rows[0][1]});
	  
      # parse table "Kursdaten" and extract its contents
      @rows = new HTML::TableExtract
	  (decode=>0, depth=>2, count=>4+$tabOffset)->parse($response->content)->rows();

      next unless (@rows);
      $info{$fund, "price"} = $info{$fund, "last"} = trimtr( $rows[4][1] );
      $info{$fund, "net"} = trimtr( $rows[2][2] );
      ($info{$fund, "time"}) = ($rows[1][0] =~ /(\d{1,2}:\d{1,2}:\d{1,2})/);
      $info{$fund, "p_change"} = trimtr( $rows[1][2] );
      $info{$fund, "year_range"} = trimtr($rows[8][1])." - ".trimtr($rows[8][2]);
      $info{$fund, "bid"} = trimtr( $rows[4][1] );
      $info{$fund, "ask"} = trimtr( $rows[5][1] );
	
      # parse table "Fondsdaten" and extract its contents
      @rows = new HTML::TableExtract
	  (decode=>0, depth=>2, count=>5+$tabOffset)->parse($response->content)->rows();

      next unless (@rows);
      $info{$fund, "exchange"} = trimtr( $rows[2][1] );
	
      $info{$fund, "success"}  = 1;
      $info{$fund, "errormsg"} = "";
    } else {
      $info{$fund, "success"}  = 0;
      $info{$fund, "errormsg"} = "HTTP error";
    }
  }

  return wantarray() ? %info : \%info;
}

1;

=head1 NAME

Finance::Quote::vwd	- Obtain quotes from vwd Vereinigte Wirtschaftsdienste GmbH.

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
ask, bid, currency, date, isodate, exchange, last, name, net,
p_change, price, symbol, time, year_range.

=head1 SEE ALSO

vwd Vereinigte Wirtschaftsdienste GmbH, http://www.vwd.de/

=cut
