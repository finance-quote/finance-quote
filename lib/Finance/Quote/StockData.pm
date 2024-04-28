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

package Finance::Quote::StockData;

use strict;
use warnings;

use Encode qw(decode);
use HTTP::Request::Common;
use JSON qw(decode_json);

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments', '###';

# VERSION

my $STOCKDATA_URL = 'https://api.stockdata.org/v1/data/quote?symbols=';
# Gets appended with '$stock&api_token=$token'

# my $user_agent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.0.0 Safari/537.36';
my $user_agent = 'Finance-Quote OpenSource Stock Quote Tool';

sub methods {
  return (stockdata => \&stockdata,
          nyse      => \&stockdata,
          nasdaq    => \&stockdata);
}

our @labels = qw/symbol name open high low last date volume currency method/;

sub labels { 
  return (stockdata => \@labels,
          nyse      => \@labels,
          nasdaq    => \@labels); 
}

sub stockdata {

  my $quoter = shift;
  my @stocks = @_;
  my (%info, $url, $reply);
  my $ua = $quoter->user_agent();
  $ua->agent($user_agent);

  my $token = exists $quoter->{module_specific_data}->{stockdata}->{API_KEY} ? 
              $quoter->{module_specific_data}->{stockdata}->{API_KEY}        :
              $ENV{"STOCKDATA_API_KEY"};

  foreach my $stock (@stocks) {

    if ( !defined $token ) {
      $info{ $stock, 'success' } = 0;
      $info{ $stock, 'errormsg' } =
        'StockData API_KEY not defined. Get an API key at https://stockdata.org';
      next;
    }

    $url   = $STOCKDATA_URL . $stock . '&api_token=' . $token;
    $reply = $ua->request( GET $url);

    my $code    = $reply->code;
    my $desc    = HTTP::Status::status_message($code);
    my $headers = $reply->headers_as_string;
    my $body    = decode('UTF-8', $reply->content);

    ### Body: $body

    my ($name, $last, $open, $high, $low, $date, $isodate, $volume, $currency, $quote);

    $info{ $stock, "symbol" } = $stock;

    if ( $code == 200 ) {

      eval {$quote = JSON::decode_json $body};
      if ($@) {
        $info{ $stock, 'success' } = 0;
        $info{ $stock, 'errormsg' } = $@;
        next;
      }

      ### [<now>] JSON quote: $quote

      if (!exists $quote->{'meta'} || $quote->{'meta'}{'returned'} != 1) {
        $info{ $stock, 'success' } = 0;
        $info{ $stock, 'errormsg' } = $@;
        next;
      }

      $name     = $quote->{'data'}[0]{'name'};
      $last     = $quote->{'data'}[0]{'price'};
      $open     = $quote->{'data'}[0]{'day_open'};
      $low      = $quote->{'data'}[0]{'day_low'};
      $high     = $quote->{'data'}[0]{'day_high'};
      $volume   = $quote->{'data'}[0]{'volume'};
      $currency = $quote->{'data'}[0]{'currency'};
      $date     = $quote->{'data'}[0]{'last_trade_time'};
      ($isodate) = $date =~ m|^([\d\-]+)T|;

      ### [<now>] isodate: $isodate

      $info{ $stock, 'name' } = $name;
      $info{ $stock, 'last' } = $last;
      $info{ $stock, 'open' } = $open;
      $info{ $stock, 'low' } = $low;
      $info{ $stock, 'high' } = $high;
      $info{ $stock, 'volume' } = $volume;
      $info{ $stock, 'currency' } = $currency;
      $quoter->store_date(\%info, $stock, {isodate => $isodate});

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

Finance::Quote::StockData - Obtain quotes from StockData.org

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = $q->fetch("foobar", "tlv");  # Only query foobar

    %info = $q->fetch("romania", "brd");     # Failover to other sources OK.

=head1 DESCRIPTION

This module fetches information from L<https://foobar.ro/>.

This module is loaded by default on a Finance::Quote object. It's also possible
to load it explicitly by placing "foobar" in the argument list to
Finance::Quote->new().

This module provides "foobar", "tradeville", "romania", and "europe"
fetch methods. It was written to replace a non-working Tradeville.pm
module.

Information obtained by this module may be covered by Bucharest Stock
Exchange terms and conditions.

=head1 LABELS RETURNED

The following labels are returned: 

=over

=item name

=item symbol

=item open

=item high

=item low

=item price

=item bid

=item ask

=item date

=item currency

=back
