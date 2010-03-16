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
# Author: Kamen Naydenov pau4o@kamennn.eu
# Revision: 0.1

package Finance::Quote::BSESofia;

use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;
use vars qw/$BSESofia_URL $VERSION/;

$VERSION = "0.7";
$BSESofia_URL = 'http://beis.bia-bg.com/bseinfo/lasttraded.php';
#$BSESofia_URL = 'http://tao/~pau4o/last-TRADED.html';

# Single share URL
# $BSESofia_URL = 'http://www.bse-sofia.bg/index.php?page=Quotes+Info&code=$firm';
# $BSESofia_URL = 'http://www.bse-sofia.bg/?page=QuotesInfo&site_lang=en&code=5alb'; # Tue Mar 16 22:49:07 2010

# trading session results
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

  sub labels {
    return (
            bulgaria => \@labels,
            bsesofia => \@labels,
            europe   => \@labels
           );
  }
}


sub bse_get {

  my $quoter = shift;   # The Finance::Quote object.

  my @stocks = @_;
  return unless @stocks;

  my %info;

  my $ua = $quoter->user_agent; # This gives us a user-agent

  my $response = $ua->request(GET $BSESofia_URL);
  unless ($response->is_success) {
    foreach my $stock (@stocks) {
      $info{$stock,"success"} = 0;
      $info{$stock,"errormsg"} = "HTTP session failed";
    }
    return wantarray() ? %info : \%info;
  }

  my $te = HTML::TableExtract->new(
                                   headers => [
                                               "BSE Code",
                                               "Last",
                                               "Average",
                                               "Volume",
                                               "Company name",
                                              ]);

  $te->parse($response->content);

  # Extract table contents.
  my @rows;
  unless (($te->tables > 0) && ( @rows = $te->rows)) {
    foreach my $stock (@stocks) {
      $info{$stock,"success"} = 0;
      $info{$stock,"errormsg"} = "Failed to parse HTML table.";
    }
    die "Няма данни за търговията на акции!";
    #  return wantarray() ? %info : \%info;
  }

  # Pack the resulting data into our structure.
  foreach my $row (@rows) {
    my $stock = shift(@$row);

    # Skip any blank lines.
    next unless $stock;
    my $re = join("|",@stocks);
    next unless $stock =~ /($re)/io;

    $info{$stock,'symbol'} = $stock;

    foreach my $label (qw/last average volume c_name/) {

      $info{$stock,$label} = shift(@$row);

      # Again, get rid of nasty high-bit characters.
      $info{$stock,$label} =~ tr/ \200-\377//d
        unless ($label eq "c_name");
      $info{$stock,$label} =~ s/(BGN)//
        if ($label =~ /(last|average)/);
    }

    # If that stock does not exist, it will have a empty
    # string for all the fields.  The "last" price should
    # always be defined (even if zero), if we see an empty
    # string here then we know we've found a bogus stock.

    if ($info{$stock,'last'} eq '') {
      $info{$stock,'success'} = 0;
      $info{$stock,'errormsg'}="Stock does not traded in last trade sesion.";
      next;
    }


    $info{$stock, "currency"} = "BGN";

    $info{$stock, "method"} = "bsesofia";
    $info{$stock, "exchange"} = "Bulgarian Stock Exchange";
    $info{$stock, "price"} = $info{$stock,"last"};
    $info{$stock, "success"} = 1;
  }

  # All done.
  return wantarray() ? %info : \%info;
}

1;

__END__

=head1 NAME

Finance::Quote::BSESofia - Obtain quotes from the Bulgarian Stock Exchange.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %stockinfo = $q->fetch("bse","VAMO");      # Only query BSESofia.
    %stockinfo = $q->fetch("bulgaria","VAMO"); # Failover to other sources OK.

=head1 DESCRIPTION

This module obtains information from the Bulgarian Stock Exchange
http://www.bse-sofia.bg/.  Only indicies from last traded session are
available.

This module is loaded by default on a Finance::Quote object.  It is
also possible to load it explicity by placing "BSESofia" in the argument
list to Finance::Quote->new().

This module provides both the "bse" and "bulgaria" fetch methods.

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

=head1 BUGS

Currently only information from last traded session can be obtained.

No failover support.

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

