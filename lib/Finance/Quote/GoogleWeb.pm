#!/usr/bin/perl -w
# vi: set ts=2 sw=2 noai ic showmode showmatch:  
#
#    Copyright (C) 2023, Bruce Schuck <bschuck@asgard-systems.com>
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

package Finance::Quote::GoogleWeb;

use strict;
use warnings;

use Encode qw(decode);
use HTML::TreeBuilder;
use HTTP::Request::Common;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments', '###';

# VERSION

my $GOOGLE_URL = 'https://www.google.com/finance/';

our $DISPLAY    = 'GoogleWeb - Scrapes www.google.com/finance/';
our @LABELS     = qw/symbol name last date currency method/;
our $METHODHASH = {subroutine => \&googleweb,
                   display    => $DISPLAY, 
                   labels     => \@LABELS};

sub methodinfo {
    return ( 
        googleweb => $METHODHASH,
        bats      => $METHODHASH,
        nyse      => $METHODHASH,
        nasdaq    => $METHODHASH,
    );
}

sub labels {
  my %m = methodinfo();
  return map {$_ => [@{$m{$_}{labels}}] } keys %m;
}

sub methods {
  my %m = methodinfo(); return map {$_ => $m{$_}{subroutine} } keys %m;
}

sub googleweb {

  my $quoter = shift;
  my @stocks = @_;
  my (%info, $tree, $url, $reply);
  my $ua = $quoter->user_agent();

  foreach my $stock (@stocks) {

    my $ucstock = uc($stock);
    $url   = $GOOGLE_URL . "quote/" . $ucstock;
    $reply = $ua->request( GET $url);

    my $code    = $reply->code;
    my $desc    = HTTP::Status::status_message($code);
    my $headers = $reply->headers_as_string;
    my $body    = decode('UTF-8', $reply->content);

    ### Body: $body

    my ($name, $last, $date, $currency, $time, $taglink, $link, $exchange);

    $info{ $stock, "symbol" } = $stock;

    if ( $code == 200 ) {

      # Use HTML::TreeBuilder to parse HTML in $body
      # Without the exchange Google returns a list of possible matches
      # For example AAPL will give you a list of links that will
      # include AAPL:NASDAQ
      $tree = HTML::TreeBuilder->new;
      if ($tree->parse_content($body)) {
        #
        # Get link with exchange appended (MUTF|NYSE|NASDAQ|NYSEAMERICAN|BATS|HKG)
        $taglink = $tree->look_down(_tag => 'a', href => qr!^./quote/$ucstock:(MUTF|NYSE|NASDAQ|NYSEAMERICAN|BATS|HKG)!);
        if ($taglink) {
          $link = $taglink->attr('href');
          $link =~ s|\./quote|quote|;
          ($exchange = $link) =~ s/.*${ucstock}://;
        } else {
          $info{ $stock, "success" } = 0;
          $info{ $stock, "errormsg" } = "$stock not found on Google Finance";
          next;
        }
      } else {  # Could not parse body into tree
        $info{ $stock, "success" } = 0;
        $info{ $stock, "errormsg" } =
          "Error retrieving quote for $stock. Could not parse HTML returned from $url.";
        next;
      }

      # Found a link that looks like STOCK:EXCHANGE
      # Fetch that link and parse
      $url = $GOOGLE_URL . $link;

      $reply = $ua->get($url);

      if ($reply->code ne "200") {
        $info{ $stock, "success" } = 0;
        $info{ $stock, "errormsg" } =
          "Error retrieving quote for $stock from $url";
        next;
      }
      
      # Parse returned HTML
      $body = decode('UTF-8', $reply->content);
      unless ($tree->parse_content($body)) {
        $info{ $stock, "success" } = 0;
        $info{ $stock, "errormsg" } =
          "Cannot parse HTML from $url";
        next;
      }

      ### Tree: $tree

      # Look for div tag with data-last-price attribute
      $taglink =
        $tree->look_down(_tag => 'div', 'data-last-price' => qr|[0-9.]+|);
      unless ($taglink) {
        $info{ $stock, "success" } = 0;
        $info{ $stock, "errormsg" } = "Cannot find price data in $url";
        next;
      }

      $last = $taglink->attr('data-last-price');
      # Google does not include .00 if the price is a whole dollar amount
      unless ( $last =~ /\./ ) {
        $last = $last . '.00';
      }
      # Also fix missing cents (15.30 will be 15.3 in the HTML)
      if ( $last =~ /\d+\.\d$/ ) {
        $last = $last . '0';
      }

      $time = $taglink->attr('data-last-normal-market-timestamp');
      $currency = $taglink->attr('data-currency-code');
      my ( undef, undef, undef, $mday, $mon, $year, undef, undef, undef ) =
        localtime($time);
      $date = sprintf("%d/%02d/%02d", $year + 1900, $mon + 1, $mday);

      $info{ $stock, 'method' } = 'googleweb';
      $info{ $stock, 'last' } = $last;
      $info{ $stock, 'currency' } = $currency;
      $info{ $stock, 'exchange' } = $exchange;
      $quoter->store_date(\%info, $stock, { isodate => $date});
      $info{ $stock, 'success' } = 1;

    } else {       # HTTP Request failed (code != 200)
      $info{ $stock, "success" } = 0;
      $info{ $stock, "errormsg" } =
        "Error retrieving quote for $stock. Attempt to fetch the URL $url resulted in HTTP response $code ($desc)";
    }

  }  

  return wantarray() ? %info : \%info;
  return \%info;

}

1;

__END__

=head1 NAME

Finance::Quote::GoogleWeb - Obtain quotes from Google Finance Web Pages

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = $q->fetch("googleweb", "aapl");  # Only query googleweb

    %info = $q->fetch("nyse", "ge");     # Failover to other sources OK.

=head1 DESCRIPTION

This module fetches information from L<https://www.google.com/finance/>.

This module is loaded by default on a Finance::Quote object. It's also possible
to load it explicitly by placing "googleweb" in the argument list to
Finance::Quote->new().

This module provides "googleweb", "bats", "nyse", and "nasdaq"
fetch methods.

=head1 LABELS RETURNED

The following labels are returned: 

=over

=item name

=item symbol

=item last

=item date

=item currency

=item method

=back

=head1 AVAILABLE EXCHANGES

While the Google Finance web pages contain price information from other
stock exchanges, this module currently retrieves last trade prices for
securities listed on the NYSE, American, BATS, and NASDAQ stock exchanges.
U.S. Mutual Funds quotes can also be retrieved with this module.
