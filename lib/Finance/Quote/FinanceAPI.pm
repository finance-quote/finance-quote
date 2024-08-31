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
our @LABELS     = qw/symbol name open high low last date volume currency method/;
our $METHODHASH = {subroutine => \&financeapi>, 
                   display => $DISPLAY, 
                   labels => \@LABELS,
                   features => $FEATURES};

sub methodinfo {
    return ( 
        <method> => $METHODHASH,
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
              $ENV{"FINANCE_API_KEY"};

  # Set headers. API key is sent as a header.
  my @ua_headers = (
    'Accept' => 'application/json',
    'X-API-KEY' => $token,
  );

  foreach my $stock (@stocks) {

    $url   = $FINANCEAPI_URL . $stock;
    $reply = $ua->get( $url, @ua_headers );

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
        if ( $tree->look_down(_tag => 'div', id => 'ctl00_body_divNoData') ) {
          $info{ $stock, "success" } = 0;
          $info{ $stock, "errormsg" } =
            "Error retrieving quote for $stock. No data returned";
          next;
        }
        $name = $tree->look_down(_tag => 'h2', class => qr/^mBot0 large textStyled/)->as_text;
        $info{ $stock, 'success' } = 1;
        ($info{ $stock, 'name' } = $name) =~ s/^\s+|\s+$//g ;
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

=item bid

=item ask

=item date

=item currency

=back
