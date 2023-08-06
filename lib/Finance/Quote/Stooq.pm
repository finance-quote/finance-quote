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

package Finance::Quote::Stooq;

use strict;
use warnings;

use Encode qw(decode);
use LWP::UserAgent;
use HTTP::Request::Common;
use HTTP::CookieJar::LWP ();
use HTML::TableExtract;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments', '###';

# VERSION

my $STOOQ_URL = 'https://stooq.com/q/?s=';

sub features() {
    return {'description' => 'Fetch quotes from stooq.com'};
}

sub methods {
  return (stooq  => \&stooq,
          europe => \&stooq,
          poland => \&stooq);
}

our @labels = qw/symbol name open high low last bid ask date currency method/;

my %currencies_by_link = (
  '?i=21' => "EUR", # Europe (€)
  '?i=23' => "GBP", # United Kingdom (£)
  '?i=25' => "HKD", # Hong Kong (HK$)
  '?i=30' => "HUF", # Hungary (Ft)
  '?i=39' => "JPY", # Japan (¥)
  '?i=60' => "PLN", # Poland (zł)
  '?i=77' => "USD", # United States ($)
);

my %currencies_by_symbol = (
  '&pound;'  => "GBP", # United Kingdom (£)
  'p.'       => "GBX", # United Kingdom (penny)
  '&euro;'   => "EUR", # Europe (€)
  'z\x{142}' => "PLN", # Poland (zł)
  '$'       => "USD", # United States ($)
  '&cent;'   => "USX", # United States (¢)
  'HK$'     => "HKD", # Hong Kong (HK$)
  '&yen;'    => "JPY", # Japan (¥)
  'Ft'       => "HUF", # Hungary (Ft)
);

sub labels { 
  return (stooq  => \@labels,
          europe => \@labels, 
          poland => \@labels);
}

sub stooq {

  my $quoter = shift;
  my @stocks = @_;
  my (%info, $tree, $table, $pricetable, $url, $reply);
  my $cj = HTTP::CookieJar::LWP->new;
#  my $ua = LWP::UserAgent->new(cookie_jar => $cj);
  my $ua = $quoter->user_agent();
  $ua->cookie_jar($cj);
  $ua->default_header('Accept-Encoding' => 'deflate');
  $ua->default_header('Accept-Language' => 'en-US,en;q=0.5');

  foreach my $stock (@stocks) {

    $url   = $STOOQ_URL . $stock;
    $reply = $ua->request( GET $url );

    my $code    = $reply->code;
    my $desc    = HTTP::Status::status_message($code);
    my $headers = $reply->headers_as_string;
    my $body    = $reply->decoded_content;

    ### Body: $body

    my ($name, $bid, $ask, $last, $open, $high, $low, $date, $currency);
    my ($te, $table);

    $info{ $stock, "symbol" } = $stock;

    if ( $code == 200 ) {

      # Use HTML::TableExtract to parse HTML in $body

      # The table with the security name is the only table
      # with bgcolor=e9e9e9 style=z-index:1
      $te = HTML::TableExtract->new(
        attribs => { bgcolor => 'e9e9e9', style => 'z-index:1' } );
      if (($te->parse($body)) && ($table = $te->first_table_found)) {
        ### NameTable Rows: $table->rows()
        ($name) = $table->cell(0,1) =~ m|^.*?(\w.*)$|;
        $te->eof;
      }

      # The table with the price data is the only table with
      # attribute id='t1'
      $te = HTML::TableExtract->new( keep_html => 1,
                                        attribs => { id => 't1' } );
      if (($te->parse($body)) && ($table = $te->first_table_found)) {
        (my $last) = $table->cell(0,0) =~ m|^.+>([\d\.]+)<|;

        # usually currency is embedded in an A tag
        #   curency default: td > b[> span_with_price] + "&nbsp;" + _a_linking_to_currency
        #   curency USD/HUF: td > b > _a_linking_to_currency + "&nbsp;" + span_with_price
        # except for commodities there's no A tag:
        #   commodities:     td > b[> span_with_price] + "&nbsp;_currency_without_link_"
        (my $currlink) = $table->cell(0,0) =~ m|<a href=t/(\?i=\d+)>|;
        if ( ($currlink) && ($currencies_by_link{$currlink}) ) {
          $currency = $currencies_by_link{$currlink};
        } else {
          (my $currsymbol) = $table->cell(0,0)
            =~ m|[\d\.]+</span></b>&nbsp;([^/]+)/(ozt\|lb\|t\|gal\|bbl\|bu\|mmBtu)|;
          if ( ($currsymbol) && ($currencies_by_symbol{$currsymbol}) ) {
            $currency = $currencies_by_symbol{$currsymbol};
          }
        }
	
        (my $date) = $table->cell(0,1) =~ m|Date.+>(\d{4}-\d{2}-\d{2})<|;
        (my $high, my $low) = $table->cell(1,1)
          =~ m|.+>([\d\.]+)<.+>([\d\.]+)<|;
        (my $open) = $table->cell(3,0) =~ m|Open.+>([\d\.]+)<|;
        (my $bid) = $table->cell(4,0) =~ m|Bid.+>([\d\.]+)<|;
        (my $ask) = $table->cell(4,1) =~ m|Ask.+>([\d\.]+)<|;
        # If last and date are defined, save values in hash
        if ( ($last) && ($date) && ($currency) ) {
          $info{ $stock, 'success' }  = 1;
          $info{ $stock, 'method' }   = 'stooq';
          $info{ $stock, 'name' }     = $name;
          $info{ $stock, 'last' }     = $last;
          $info{ $stock, 'currency' } = $currency;
          $info{ $stock, 'open' }     = $open;
          $info{ $stock, 'high' }     = $high;
          $info{ $stock, 'low' }      = $low;
          $info{ $stock, 'bid' }      = $bid if ($bid);
          $info{ $stock, 'ask' }      = $ask if ($ask);
          $quoter->store_date(\%info, $stock, { isodate => $date });
          # Adjust/scale price data if currency is GBX (GBp) or USX (USc)
          if ( ( $currency eq 'GBX' ) || ( $currency eq 'USX' ) ) {
            foreach my $field ( $quoter->default_currency_fields ) {
              next unless ( $info{ $stock, $field } );
              $info{ $stock, $field } =
                $quoter->scale_field( $info{ $stock, $field }, 0.01 );
            }
            if ( $info{ $stock, 'currency' } eq 'GBX' ) {
              $info{ $stock, 'currency' } = 'GBP';
            } else {
              $info{ $stock, 'currency' } = 'USD';
            }
          }
        }
      } else {
        $te->eof;
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

Finance::Quote::stooq - Obtain quotes from stooq Stock Exchange.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = $q->fetch("stooq", "ISLN.UK");  # Only query stooq

    %info = $q->fetch("poland", "LRQ");     # Failover to other sources OK.

=head1 DESCRIPTION

This module fetches information from L<https://stooq.com/>.

This module is loaded by default on a Finance::Quote object. It's also possible
to load it explicitly by placing "stooq" in the argument list to
Finance::Quote->new().

This module provides "stooq", "poland", and "europe" fetch methods.

Information obtained by this module may be covered by Warsaw Stock
Exchange terms and conditions.

=head1 LABELS RETURNED

The following labels are returned: 

=over

=item name

=item symbol

=item open

=item high

=item low

=item last

=item bid

=item ask

=item date

=item currency

=back
