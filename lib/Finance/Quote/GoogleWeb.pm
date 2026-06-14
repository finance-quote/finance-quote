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
use HTTP::Request::Common;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments', '###';

# VERSION

my $GOOGLE_URL   = 'https://www.google.com/finance/quote/';

# Endpoint used by the Google Finance search box to resolve a ticker
# symbol to its primary listing (exchange). It returns the same
# autocomplete suggestions a user sees while typing in the search box.
my $SEARCH_URL   = 'https://www.google.com/complete/search?client=finance-immersive&q=';

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
  my (%info, $url, $reply);
  my $ua = $quoter->user_agent();

  foreach my $stock (@stocks) {

    my $ucstock = uc($stock);

    $info{ $stock, "symbol" } = $stock;

    # ---------------------------------------------------------------
    # Step 1: resolve the symbol to its primary exchange.
    #
    # The Google Finance quote URL requires the exchange to be appended
    # (e.g. AAPL:NASDAQ). The plain quote/AAPL page no longer returns a
    # list of disambiguation links, so instead we query the same
    # autocomplete endpoint the search box uses. Its first suggestion
    # for an exact ticker match is the primary listing.
    # ---------------------------------------------------------------
    $url   = $SEARCH_URL . $ucstock;
    $reply = $ua->request( GET $url );

    my $code = $reply->code;
    my $desc = HTTP::Status::status_message($code);

    unless ( $code == 200 ) {
      $info{ $stock, "success" } = 0;
      $info{ $stock, "errormsg" } =
        "Error retrieving quote for $stock. Attempt to fetch the URL $url resulted in HTTP response $code ($desc)";
      next;
    }

    my $body = decode('UTF-8', $reply->content);

    ### Search Body: $body

    my ($name, $last, $date, $currency, $time, $exchange);

    # Each suggestion carries a small metadata object with the ticker
    # ("t"), exchange ("x") and company name ("c"). Pick the first one
    # whose ticker matches the requested symbol exactly.
    while ( $body =~ /\{([^{}]*)\}/g ) {
      my $obj = $1;
      next unless $obj =~ /"t":"([^"]*)"/ && uc($1) eq $ucstock;
      ($exchange) = $obj =~ /"x":"([^"]*)"/;
      ($name)     = $obj =~ /"c":"([^"]*)"/;
      last if $exchange;
    }

    unless ($exchange) {
      $info{ $stock, "success" } = 0;
      $info{ $stock, "errormsg" } = "$stock not found on Google Finance";
      next;
    }

    # ---------------------------------------------------------------
    # Step 2: fetch the quote page for SYMBOL:EXCHANGE and pull the
    # price, currency and trade time from the embedded data.
    #
    # The page no longer exposes data-last-price style attributes and
    # its CSS class names are obfuscated, but it still embeds a JSON
    # blob that includes, in a fixed order:
    #
    #   ["AAPL","NASDAQ"],"Apple Inc",0,"USD",[291.13,...],...,[1781310600]
    #    \_ symbol/exchange  \_ name      \_ currency \_ price       \_ epoch
    # ---------------------------------------------------------------
    $url   = $GOOGLE_URL . $ucstock . ':' . $exchange;
    $reply = $ua->request( GET $url );

    if ( $reply->code != 200 ) {
      $info{ $stock, "success" } = 0;
      $info{ $stock, "errormsg" } =
        "Error retrieving quote for $stock from $url";
      next;
    }

    $body = decode('UTF-8', $reply->content);

    ### Quote Body: $body

    if ( $body =~ /\["\Q$ucstock\E","\Q$exchange\E"\],"(?:[^"\\]|\\.)*",\d+,"([A-Z]{2,4})",\[(-?[\d.]+),.{0,300}?,\[(\d{6,})\]/s ) {
      ( $currency, $last, $time ) = ( $1, $2, $3 );
    } else {
      $info{ $stock, "success" } = 0;
      $info{ $stock, "errormsg" } = "Cannot find price data in $url";
      next;
    }

    my ( undef, undef, undef, $mday, $mon, $year, undef, undef, undef ) =
      localtime($time);
    $date = sprintf("%d/%02d/%02d", $year + 1900, $mon + 1, $mday);

    $info{ $stock, 'method' }   = 'googleweb';
    $info{ $stock, 'name' }     = $name if defined $name;
    $info{ $stock, 'last' }     = $last;
    $info{ $stock, 'currency' } = $currency;
    $info{ $stock, 'exchange' } = $exchange;
    $quoter->store_date(\%info, $stock, { isodate => $date });
    $info{ $stock, 'success' }  = 1;

  }

  return wantarray() ? %info : \%info;

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
