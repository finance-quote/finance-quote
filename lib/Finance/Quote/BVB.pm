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
#    Written as a replacement for Tradeville.pm.

package Finance::Quote::BVB;

use strict;
use warnings;

use Encode qw(decode);
use HTTP::Request::Common;
use HTML::TreeBuilder;
use HTML::TableExtract;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments', '###';

# VERSION

my $BVB_URL = 'https://bvb.ro/FinancialInstruments/Details/FinancialInstrumentsDetails.aspx?s=';

sub methods {
  return (bvb        => \&bvb,
          romania    => \&bvb,
          tradeville => \&bvb,
          europe     => \&bvb);
}

our @labels = qw/symbol name open high low last bid ask date currency method/;

sub labels { 
  return (bvb        => \@labels,
          romania    => \@labels,
          tradeville => \@labels,
          europe     => \@labels); 
}

sub bvb {

  my $quoter = shift;
  my @stocks = @_;
  my (%info, $tree, $table, $pricetable, $url, $reply);
  my $ua = $quoter->user_agent();

  foreach my $stock (@stocks) {

    $url   = $BVB_URL . $stock;
    $reply = $ua->request( GET $url);

    my $code    = $reply->code;
    my $desc    = HTTP::Status::status_message($code);
    my $headers = $reply->headers_as_string;
    my $body    = decode('UTF-8', $reply->content);

    ### Body: $body

    my ($name, $bid, $ask, $last, $open, $high, $low, $date);

    $info{ $stock, "symbol" } = $stock;

    if ( $code == 200 ) {

      # Use HTML::TreeBuilder to parse HTML in $body
      $tree = HTML::TreeBuilder->new;
      if ($tree->parse($body)) {

        $tree->eof;
        $name = $tree->look_down(_tag => 'h2', class => qr/^mBot0 large textStyled/)->as_text;
        $info{ $stock, 'success' } = 1;
        $info{ $stock, 'name' } = $name;
        $info{ $stock, 'currency' } = 'RON';
        $info{ $stock, 'method' } = 'bvb';
        $table = $tree->look_down(_tag => 'table', id => qr/^ctl00_body_ctl02_PricesControl_dvCPrices/)->as_HTML;
        $pricetable = HTML::TableExtract->new();
        $pricetable->parse($table);
        foreach my $row ($pricetable->rows) {
          if ( @$row[0] =~ m/Ask$/ ) {
            ($bid, $ask) = @$row[1] =~ m|^\s+([\d\.]+)\s+\/\s+([\d\.]+)|;
            $info{ $stock, 'bid' } = $bid;
            $info{ $stock, 'ask' } = $ask;
          }
          elsif ( @$row[0] =~ m|^Date/time| ) {
            ($date) = @$row[1] =~ m|^([\d/]+)\s|;
            $quoter->store_date(\%info, $stock, {usdate => $1}) if $date =~ m|([0-9]{1,2}/[0-9]{2}/[0-9]{4})|;
          }
          elsif ( @$row[0] =~ m|^Last price| ) {
            ($last) = @$row[1] =~ m|^([\d\.]+)|;
            $info{ $stock, 'last' } = $last;
          }
          elsif ( @$row[0] =~ m|^Open price| ) {
            ($open) = @$row[1] =~ m|^([\d\.]+)|;
            $info{ $stock, 'open' } = $open;
          }
          elsif ( @$row[0] =~ m|^High price| ) {
            ($high) = @$row[1] =~ m|^([\d\.]+)|;
            $info{ $stock, 'high' } = $high;
          }
          elsif ( @$row[0] =~ m|^Low price| ) {
            ($low) = @$row[1] =~ m|^([\d\.]+)|;
            $info{ $stock, 'low' } = $low;
          }
        }

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

Finance::Quote::BVB - Obtain quotes from Bucharest Stock Exchange.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("bvb", "tlv");  # Only query bvb
    %info = Finance::Quote->fetch("romania", "brd");     # Failover to other sources OK.

=head1 DESCRIPTION

This module fetches information from L<https://bvb.ro/>.

This module is loaded by default on a Finance::Quote object. It's also possible
to load it explicitly by placing "bvb" in the argument list to
Finance::Quote->new().

This module provides "bvb", "tradeville", "romania", and "europe"
fetch methods. It was written to replace a non-working Tradeville.pm
module.

Information obtained by this module may be covered by Bucharest Stock
Exchange terms and conditions.

=head1 LABELS RETURNED

The following labels are returned: 

=over

=item *

name

=item *

symbol

=item *

open

=item *

high

=item *

low

=item *

price

=item *

bid

=item *

ask

=item *

date

=item *

currency (always RON)

=back
