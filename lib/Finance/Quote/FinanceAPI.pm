#!/usr/bin/perl -w
# vi: set ts=2 sw=2 noai ic showmode showmatch:  
#
#    Copyright (C) 2024, Bruce Schuck <bschuck@asgard-systems.com>
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

#    Changes:
#    Initial Version: 2024-08-31, Bruce Schuck

package Finance::Quote::FinanceAPI;

use strict;
use warnings;

use Encode qw(decode);
use HTTP::Request::Common;
use JSON qw( decode_json );

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments', '###';

# VERSION

my $FINANCEAPI_URL = 'https://yfapi.net/v6/finance/quote?region=US&lang=en&symbols=';

# Change DISPLAY and method values in code below
# Modify LABELS to those returned by the method

our $DISPLAY    = 'FinanceAPI';
our $FEATURES   = {'API_KEY' => 'registered user API key'};
our @LABELS     = qw/symbol name open high low last price date volume currency method/;
our $METHODHASH = {subroutine => \&financeapi, 
                   display => $DISPLAY, 
                   labels => \@LABELS,
                   features => $FEATURES};

sub methodinfo {
    return ( 
        financeapi   => $METHODHASH,
        nyse         => $METHODHASH,
        nasdaq       => $METHODHASH,
        usa          => $METHODHASH,
    );
}

sub labels { my %m = methodinfo(); return map {$_ => [@{$m{$_}{labels}}] } keys %m; }

sub methods {
  my %m = methodinfo(); return map {$_ => $m{$_}{subroutine} } keys %m;
}

sub financeapi {

  my $quoter = shift;
  my @stocks = @_;
  my (%info, $url, $reply);
  my $ua = $quoter->user_agent();

  # Set token. If not passed in as argument, get from environment.
  my $token = exists $quoter->{module_specific_data}->{stockdata}->{API_KEY} ? 
              $quoter->{module_specific_data}->{stockdata}->{API_KEY}        :
              $ENV{"FINANCEAPI_API_KEY"};

  # Set headers. API key is sent as a header.
  my @ua_headers = (
    'Accept' => 'application/json',
    'X-API-KEY' => $token,
  );

  foreach my $stock (@stocks) {

    if ( !defined $token ) {
      $info{ $stock, 'success' } = 0;
      $info{ $stock, 'errormsg' } =
        'FINANCEAPI_API_KEY not defined. Get an API key at https://financeapi.net/';
      next;
    }

    $url   = $FINANCEAPI_URL . $stock;
    $reply = $ua->get( $url, @ua_headers );

    my $code    = $reply->code;
    my $desc    = HTTP::Status::status_message($code);
    my $headers = $reply->headers_as_string;
    my $body    = $reply->content;

    ### Body: $body

    my ($quote, $name, $bid, $ask, $last, $open, $high, $low, $volume, $currency, $date);
    my ($month, $day, $year);

    $info{ $stock, "symbol" } = $stock;

    if ( $code == 200 ) {

      eval {$quote = JSON::decode_json $body};
      if ($@) {
        $info{ $stock, 'success' } = 0;
        $info{ $stock, 'errormsg' } = $@;
        next;
      }

      ### [<now>] JSON quote: $quote

      if (!exists $quote->{'quoteResponse'}) {
        $info{ $stock, 'success' } = 0;
        $info{ $stock, 'errormsg' } = $@;
        next;
      }

      $name     = $quote->{'quoteResponse'}{'result'}[0]{'longName'};
      $open     = $quote->{'quoteResponse'}{'result'}[0]{'regularMarketOpen'};
      $high     = $quote->{'quoteResponse'}{'result'}[0]{'regularMarketDayHigh'};
      $low      = $quote->{'quoteResponse'}{'result'}[0]{'regularMarketDayLow'};
      $last     = $quote->{'quoteResponse'}{'result'}[0]{'regularMarketPrice'};
      $volume   = $quote->{'quoteResponse'}{'result'}[0]{'regularMarketVolume'};
      #$currency = $quote->{'quoteResponse'}{'result'}[0]{'financialCurrency'};
      $currency = $quote->{'quoteResponse'}{'result'}[0]{'currency'};
      $date     = $quote->{'quoteResponse'}{'result'}[0]{'regularMarketTime'};
      ($month, $day, $year) = (localtime($date))[4,3,5];
      $month++;
      $year += 1900;

      $info{$stock, 'name'}      = $name;
      $info{$stock, 'open'}      = $open;
      $info{$stock, 'high'}      = $high;
      $info{$stock, 'low'}       = $low;
      $info{$stock, 'last'}      = $last;
      $info{$stock, 'price'}     = $last;
      $info{$stock, 'volume'}    = $volume;
      $info{$stock, 'currency'}  = $currency;
      $info{ $stock, 'method' }  = 'financeapi';
      $quoter->store_date(\%info, $stock, {month => $month, day => $day, year => $year});

      # Check for stocks traded in pence instead of pounds
      # Convert GBp or GBX to GBP (divide price by 100).
      # GBP.L - pence
      # GBPG.L - pounds

      if ( ($info{$stock,"currency"} eq "GBp") ||
         ($info{$stock,"currency"} eq "GBX")) {
        foreach my $field ( $quoter->default_currency_fields ) {
          next unless ( $info{ $stock, $field } );
          $info{ $stock, $field }
            = $quoter->scale_field( $info{ $stock, $field }, 0.01 );
        }
        $info{ $stock, "currency"} = "GBP";
      }

      # Apply the same hack for Johannesburg Stock Exchange
      # (JSE) prices as they are returned in ZAc (cents)
      # instead of ZAR (rands). JSE symbols are suffixed
      # with ".JO" when querying Yahoo e.g. ANG.JO

      if ($info{$stock,"currency"} eq "ZAc") {
        foreach my $field ( $quoter->default_currency_fields ) {
          next unless ( $info{ $stock, $field } );
          $info{ $stock, $field }
            = $quoter->scale_field( $info{ $stock, $field }, 0.01 );
        }
        $info{ $stock, "currency"} = "ZAR";
      }

      # Apply the same hack for Tel Aviv Stock Exchange
      # (TASE) prices as they are returned in ILA (Agorot)
      # instead of ILS (Shekels). TASE symbols are suffixed
      # with ".TA" when querying Yahoo e.g. POLI.TA

      if ($info{$stock,"currency"} eq "ILA") {
        foreach my $field ( $quoter->default_currency_fields ) {
          next unless ( $info{ $stock, $field } );
          $info{ $stock, $field }
            = $quoter->scale_field( $info{ $stock, $field }, 0.01 );
        }
        $info{ $stock, "currency"} = "ILS";
      }

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

Finance::Quote::FinanceAPI - Obtain quotes from financeapi.net.

=head1 SYNOPSIS

    use Finance::Quote;

    # API Key passed during object creation
    $q = Finance::Quote->new('FinanceAPI', financeapi => {API_KEY => 'your-financeapi-api-key'});

    # FINANCEAPI_API_KEY environment variable set
    $q = Finance::Quote->new;

    %info = $q->fetch("financeapi", "AAPL");  # Only query financeapi

=head1 DESCRIPTION

This module fetches information from L<https://financeapi.net/>. The API URL
is https://yfapi.net/.

This module is loaded by default on a Finance::Quote object. It's also possible
to load it explicitly by placing "financeapi" in the argument list to
Finance::Quote->new().

This module provides the "financeapi" fetch method. In addition it
advertises "nyse", "usa", and "nasdaq".

=head1 API_KEY

L<https://financeapi.net/> requires users to register for an API Key
(token).
The free "Basic" API Key allows 100 queries per day and a 300 per minute
rate.

The API key may be set by either providing a module specific hash to
Finance::Quote->new as in the above example, or by setting the environment
variable FINANCEAPI_API_KEY.

=head1 LABELS RETURNED

The following labels are returned: 

=over

=item name

=item symbol

=item open

=item high

=item low

=item price

=item date

=item volume

=item currency

=back

=cut
