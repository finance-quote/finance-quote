#!/usr/bin/perl
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
# Author: Kamen Naydenov <pau4o@kamennn.eu>
# Revision: 0.7

package Finance::Quote::BSESofia;

use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;

use vars qw/$BSESofia_URL $VERSION/;

$VERSION = "0.7";

# Single share URL
#$BSESofia_URL = 'http://www.bse-sofia.bg/?page=QuotesInfo&site_lang=en&code='; # Tue Mar 16 22:49:07 2010
$BSESofia_URL = 'http://localhost/~pau4o/singleShare.html?page=QuotesInfo&site_lang=en&code=';

# trading session results
#$BSESofia_URL = 'http://beis.bia-bg.com/bseinfo/lasttraded.php';
# $BSESofia_URL = 'http://www.bse-sofia.bg/?page=SessionResults'; # Tue Mar 16 22:49:40 2010


sub methods {
    return (
        bulgaria => \&bse_get,
        bsesofia => \&bse_get,
        europe   => \&bse_get
    );
}

{
    my @labels = qw/price last symbol volume average method currency c_name exchange/;
                   #volume high low last average change
    sub labels {
        return (
            bulgaria => \@labels,
            bsesofia => \@labels,
            europe   => \@labels
        );
    }
}

# remove all non-ASCII characters and strip
# spaces
sub justASCII {
    my $nonASCII =  shift;
    $nonASCII =~ tr/\200-\377//d;
    $nonASCII =~ s/^\s*//; # leading spaces
    $nonASCII =~ s/\s*$//; # trailing spaces
    return $nonASCII;
}

sub bse_get {

  my $quoter = shift;   # The Finance::Quote object.

  my @stocks = @_;
  return unless @stocks;

  my %info;

  my $ua = $quoter->user_agent; # This gives us a user-agent
  $ua->agent("Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.8.1.3) Gecko/20070310 Iceweasel/2.0.0.3 (Debian-2.0.0.3-1)");

  foreach my $stock (@stocks) {
      my $response = $ua->request(GET $BSESofia_URL . $stock);

      $info{$stock,'symbol'} = $stock;

      unless ($response->is_success) {
          foreach my $stock (@stocks) {
              $info{$stock,"success"} = 0;
              $info{$stock,"errormsg"} = "HTTP error";
          }
          Debug(%info); # DEBUG
          return wantarray() ? %info : \%info;
      }

      ####################
      # dividents and name
      ####################
      my $te = HTML::TableExtract->new(
          depth => 0,
          count => 0,
      ); # first top level table

      $te->parse($response->content);

      # check that we are looking for right share
      my $share = $te->first_table_found->space(2,0);
      $share = justASCII($share);
      unless ($share =~ /$stock/i) {
          $info{$stock,"success"} = 0;
          $info{$stock,"errormsg"} = "Can't find info about $stock.";
          Debug(%info); # DEBUG
          next;
      }

      my $table = $te->first_table_found();
      my $i;
      foreach my $label (qw/symbol name nominal div_date div div_yield last_price last_open/) {
          my $cellContent = $table->space(2, $i++);
          $cellContent = justASCII($cellContent);
          $info{$stock,$label} = $cellContent;
      }
      # fallback date and price - "Open Price ... (in quoting currency) As of ... date"
      $info{$stock,"last"} = $info{$stock,'last_price'};
      $quoter->store_date(\%info, $stock, {isodate => $info{$stock,'last_open'}});


      undef $te;
      undef $table;
      undef $i;
      ######################################################
      # Last trading session results and best current offers
      ######################################################
      $te = HTML::TableExtract->new(
          depth => 0,
          count => 1,
      ); # second top level table

      $te->parse($response->content);

      my $tableCheck = $te->first_table_found->space(0,0);
      $tableCheck =~ s/^(.*:\D+)//; # strip all except date

      # check page layout changes
      unless ( $1 =~ /Last trading session results and best current offers/) {
          $info{$stock,"success"} = 0;
          $info{$stock,"errormsg"} = "Failed to parse second HTML table.";
          Debug(%info); # DEBUG
          next;
      }

      $table = $te->first_table_found();
      foreach my $label (qw/volume high low last average p_change/) {
          my $cellContent = $table->space(3, $i++);
          $cellContent = justASCII($cellContent);

          if ( $label eq 'last') { # last from Last Traded Session
              if ($cellContent !~ /^0\.0*$/) { # we have newer info
                  $info{$stock,$label} = $cellContent;
                  $quoter->store_date(\%info, $stock, {isodate => $tableCheck});
              }
          }
          else {
              $info{$stock,$label} = $cellContent;
          }
      }

      $info{$stock, "currency"} = "BGN";
      $info{$stock, "method"} = "bsesofia";
      $info{$stock, "exchange"} = "Bulgarian Stock Exchange";
      $info{$stock, "success"} = 1;
#####################################################################
      Debug(%info); # DEBUG

      sub Debug {
          my %ofni = (@_);
          print STDERR "\n==================================\n";
          foreach ( sort keys %ofni) {
              my $value = $ofni{$_};
              s/\W/_/;
              print STDERR $_, ' => ', $value, "\n";
          }
          print STDERR "==================================\n\n";
      }
#####################################################################
  }
  return wantarray() ? %info : \%info;
}

1;

__END__

=head1 NAME

Finance::Quote::BSESofia - Obtain quotes from the Bulgarian Stock Exchange.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %stockinfo = $q->fetch("bsesofia","VAMO");      # Only query BSESofia.
    %stockinfo = $q->fetch("bulgaria","VAMO"); # Failover to other sources OK.

=head1 DESCRIPTION

This module obtains information from the Bulgarian Stock Exchange
http://www.bse-sofia.bg/.

This module is loaded by default on a Finance::Quote object.  It is
also possible to load it explicity by placing "BSESofia" in the argument
list to Finance::Quote->new().

This module provides both the "bsesofia", "bulgaria" and "europe"
fetch methods. Second and third are aliases of first method.

Information returned by this module is governed by the Bulgarian
Stock Exchange's terms and conditions.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::BSESofia:

    price        Last Price
    last         Last Price
    volume       Volume
    symbol       A unique code used by the Bulgarian Stock Exchange (BSE Sofia)
                 for trading, clearing & settlement purposes.
    volume       The number of securities traded on last session.
    average      Average Price
    method       The module (as could be passed to fetch) which found
                 this information.
    currency     In which currency is price information.
    c_name       Company or Mutual Fund Long Name
    exchange     The exchange the information was obtained from.


If all stock lookups fail (possibly because of a failed connection) then
the empty list may be returned, or undef in a scalar context.

=head1 COPYRIGHT

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or (at
your option) any later version.

Other copyrights and conditions may apply to data fetched through this
module.

=head1 AUTHORS

  Kamen Naydenov <pau4o@kamennn.eu>

=head1 SEE ALSO

Bulgarian Stock Exchange, http://www.bse-sofia.bg/

Finance::Quote

=cut

