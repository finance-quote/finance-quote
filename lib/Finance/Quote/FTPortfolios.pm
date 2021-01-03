#!/usr/bin/perl -w
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@cpan.org>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#    Copyright (C) 2000, Keith Refson <Keith.Refson@earth.ox.ac.uk>
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
#    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
#    02110-1301, USA
#
#
# This code derived from Padzensky's work on package Finance::YahooQuote,
# but extends its capabilites to encompas a greater number of data sources.
#
# This code was developed as part of GnuCash <http://www.gnucash.org/>

package Finance::Quote::FTPortfolios;

use strict;

use vars qw( $FTPORTFOLIOS_URL );

use WWW::Mechanize;
use LWP::UserAgent;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

# VERSION

$FTPORTFOLIOS_URL = "http://www.ftportfolios.com";

sub methods { return (ftportfolios => \&ftportfolios, ftportfolios_direct => \&ftportfolios); }

{
        my @labels = qw/exchange method source name currency nav pop price/;

	sub labels { return (ftportfolios => \@labels,
	                     ftportfolios_direct => \@labels); }
}

# =======================================================================

sub ftportfolios
{
    my $quoter  = shift;
    my @symbols = @_;
    my $ua      = $quoter->user_agent();

    return unless @symbols;
  

    #my @headers = (
    #    'User-Agent'      => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 11_1_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.88 Safari/537.36',
    #    'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
    #    'Accept-Encoding' => 'gzip, deflate, br',
    #    'Accept-Language' => 'en-US,en;q=0.9'
    #    );

    foreach my $trust (@symbols) {
    
      my $mech = WWW::Mechanize->new();
      $mech->get($FTPORTFOLIOS_URL);
      $mech->form_id('form1');
      $mech->field('ctl00$SearchControl$txtProductSearch', $trust);

      my $result = $mech->click('ctl00$SearchControl$btnProductSearch');
      my $body = gunzip $result->content;

      ### result : $result

      ### html : $body
      
      next;

      #my $home = $ua->get($FTPORTFOLIOS_URL, @headers);
      #my $form = HTML::Form->parse($home);

      # home  : $home
      # form  : $form
      # trust : $trust

      #$form->value('SearchControl_txtProductSearch' => $trust);
      #$form->action('https://www.ftportfolios.com/retail/ProductSearch.aspx');

      #my $click = $form->click('ctl00$SearchControl$btnProductSearch');
      #$click->header(@headers);

      # click  : $click
      
      #my $reply = $ua->request($click);

      # reply  : $reply

#      my $te = HTML::TableExtract->new();
#      $trust = $_;
#
#      my $mech = WWW::Mechanize->new();
#      $mech->get($FTPORTFOLIOS_URL);
#      $mech->dump_forms;
#
#      continue;
#
#      my $reply;
#
#      $te->utf8_mode(1);
#      $te->parse($reply->content);
#
#      $aa {$trust, "symbol"} = $trust;
#
#      # Parse the fund name and the ticker symbol.
#      $ts = $te->table(2, 2);
#      if( !defined ($ts)) {
#	  $aa {$trust, "success"} = 0;
#	  $aa {$trust, "errormsg"} = "Fund name $trust is not found.  See \"$FTPORTFOLIOS_URL\"";
#	  next;
#      }
#
#      my $row = $ts->row(0);
#      my ($a, $b) = (@$row[0]) =~ /^([-+.,\w\s]+).*Ticker: ([\w]+)/;
#      # print STDERR "name |$a|, ticker |$b|\n";
#      if (!defined($a)) {
#	  $aa {$trust, "success"} = 0;
#	  $aa {$trust, "errormsg"} = "Failure parsing fund name.";
#	  next;
#      }
#      $aa {$trust, "name"} = $a;
#
#      # Now parse the NAV and POP values
#      $ts = $te->table(6, 1);
#      foreach $row ($ts->rows) {
#
#	  # Remove leading and trailing white space
#	  $row->[0] =~ s/^\s*(.+?)\s*$/$1/ if defined($row->[0]);
#	  $row->[1] =~ s/^\s*(.+?)\s*$/$1/ if defined($row->[1]);
#
#	  # Map the row into our data array
#	  for ($row->[0]) {
#	      /^NAV/	&& do { $aa{$trust, "nav"} = $row->[1]; last; };
#	      /^POP/	&& do { $aa{$trust, "pop"} = $row->[1];
#				$aa{$trust, "price"} = $row->[1]; last; };
#
#	      $aa{$trust, "success"} = 1;
#	  };
#      }
#
#      $aa {$trust, "exchange"} = "Ftportfolios";
#      $aa {$trust, "method"} = "ftportfolios";
#      $aa {$trust, "source"} = "http://www.ftportfolios.com/";
#      if ($aa{$trust, "success"} == 1) {
#	  $aa{$trust, "currency"} = "USD";
#	  $aa{$_} =~ s/\$// foreach (keys %aa);
#
#	  # Parse out the transaction date.
#	  $reply->content =~ m/Trade Date:[^0-9]+([0-9\/]+)/s;
#	  # print STDERR "Date: $1\n";
#	  $quoter->store_date(\%aa, $trust, {usdate => $1});
#      } else {
#	  $aa{$trust, "errormsg"} = "Cannot parse quote data";
#      }
    }
#    return %aa if wantarray;
#    return \%aa;
}

1;

=head1 NAME

Finance::Quote::FTPortfolios	- Obtain unit trust prices from www.ftportfolios.com

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %stockinfo = $q->fetch("ftportfolios","FKYGTX"); # Can failover to other methods
    %stockinfo = $q->fetch("ftportfolios_direct","FKYGTX"); # Use this module only.

=head1 DESCRIPTION

This module obtains information about unit trust prices from
www.ftportfolios.com.  The information source "ftportfolios" can be used
if the source of prices is irrelevant, and "ftportfolios_direct" if you
specifically want to use ftportfolios.com.

=head1 LABELS RETURNED

Information available from Ftportfolios may include the following labels:
exchange method source name currency nav pop price.

=head1 SEE ALSO

First Trust Portfolios website - http://www.ftportfolios.com/


=cut
