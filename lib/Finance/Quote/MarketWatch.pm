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

package Finance::Quote::MarketWatch;

use strict;
use warnings;

use Encode qw(decode);
use HTTP::Request::Common;
use HTML::TreeBuilder;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments', '###';

# VERSION

my $MW_URL = 'https://www.marketwatch.com/investing/stock/';

sub methods {
  return (marketwatch => \&marketwatch,
          nyse        => \&marketwatch,
          nasdaq      => \&marketwatch);
}

our @labels = qw/symbol name last date currency method/;

sub labels { 
  return (marketwatch => \@labels,
          nyse        => \@labels,
          nasdaq      => \@labels); 
}

sub marketwatch {

  my $quoter = shift;
  my @stocks = @_;
  my (%info, $tree, $url, $reply);
  my $ua = $quoter->user_agent();

  foreach my $stock (@stocks) {

    $url   = $MW_URL . $stock;
    $reply = $ua->get($url);

    my $code    = $reply->code;
    my $desc    = HTTP::Status::status_message($code);
    my $headers = $reply->headers_as_string;
    my $body    = decode('UTF-8', $reply->content);

    ### Body: $body

    my ($name, $last, $open, $date, $currency, $metatag);
    my (%datehash, @timearray, $timestring);

    $info{ $stock, "symbol" } = $stock;

    if ( $code == 200 ) {

      # Use HTML::TreeBuilder to parse HTML in $body
      $tree = HTML::TreeBuilder->new;
      if ($tree->parse($body)) {

        $tree->eof;

        $info{ $stock, 'success' } = 1;

        $metatag = $tree->look_down(_tag => 'meta', name => 'name');
        $info{ $stock, 'name' } = $metatag->attr('content');

        $metatag = $tree->look_down(_tag => 'meta', name => 'tickerSymbol');
        $info{ $stock, 'symbol' } = $metatag->attr('content');

        $metatag = $tree->look_down(_tag => 'meta', name => 'price');
        $info{ $stock, 'last' } = $metatag->attr('content');

        $metatag = $tree->look_down(_tag => 'meta', name => 'priceCurrency');
        $info{ $stock, 'currency' } = $metatag->attr('content');

        $metatag = $tree->look_down(_tag => 'meta', name => 'quoteTime');
        $date = $metatag->attr('content');
        @timearray = split / /, $date;
        $timearray[1] =~ s/[^0-9]//g;
        %datehash = (
          year  => $timearray[2],
          month => $timearray[0],
          day   => $timearray[1] );
        ($timestring = $timearray[4]) =~ s|\.||g;
        $quoter->store_date(\%info, $stock, \%datehash);

      } else {
        $tree->eof;
        $info{ $stock, "success" } = 0;
        $info{ $stock, "errormsg" } =
          "Error retrieving quote for $stock. Could not parse HTML returned from $url.";
      }

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

Finance::Quote::MarketWatch - Obtain quotes from MarketWatch Website

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = $q->fetch("marketwatch", "aapl");  # Only query marketwatch

    %info = $q->fetch("nyse", "f");     # Failover to other sources OK.

=head1 DESCRIPTION

This module fetches information from L<https://www.marketwatch.com/>.

This module is loaded by default on a Finance::Quote object. It's also possible
to load it explicitly by placing "marketwatch" in the argument list to
Finance::Quote->new().

This module provides "marketwatch", "nyse", and "nasdaq"
fetch methods.

=head1 LABELS RETURNED

The following labels are returned: 

=over

=item name

=item symbol

=item last

=item date

=item currency

=back
