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
#
#    2024-10-06 Complete rewrite of module for F::Q issue #414

package Finance::Quote::OnVista;

use strict;
use warnings;

use Encode qw(encode_utf8);
use HTML::TreeBuilder;
use HTTP::Request::Common;
use JSON qw( decode_json );
use Date::Parse qw(str2time);
use POSIX qw(strftime);

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments', '###';

# VERSION

my $ONVISTA_URL = 'https://www.onvista.de/suche/';

# Change DISPLAY and method values in code below
# Modify LABELS to those returned by the method

our $DISPLAY    = 'OnVista - Germany';
our $FEATURES   = { 'EXCHANGE' => 'select market place (i.e. "GER", "Xetra", "Tradegate")' };
our @LABELS     = qw/symbol isin wkn name open close high low last date volume currency exchange method ask bid change p_change time exchanges source/;
our $METHODHASH = {subroutine => \&onvista,
                   display => $DISPLAY,
                   labels => \@LABELS,
                   features => $FEATURES};

sub methodinfo {
    return ( 
        onvista => $METHODHASH,
    );
}

sub labels { my %m = methodinfo(); return map {$_ => [@{$m{$_}{labels}}] } keys %m; }

sub methods {
  my %m = methodinfo(); return map {$_ => $m{$_}{subroutine} } keys %m;
}

sub onvista {

  my $quoter = shift;
  my @stocks = @_;
  my (%info, $tree, $url, $reply, $json, $json_decoded);
  my $ua = $quoter->user_agent();

  foreach my $stock (@stocks) {

    $url   = $ONVISTA_URL . $stock;
    $reply = $ua->request( GET $url);

    my $code    = $reply->code;
    my $desc    = HTTP::Status::status_message($code);
    my $headers = $reply->headers_as_string;
    my $body    = $reply->decoded_content;

    ### Body: $body

    if ( $code == 200 ) {

      # Use HTML::TreeBuilder to parse HTML in $body
      $tree = HTML::TreeBuilder->new;
      if ($tree->parse($body)) {

        $tree->eof;
        unless ( $json = encode_utf8 (($tree->look_down(_tag => 'script', id => '__NEXT_DATA__', type => 'application/json')->content_list())[0]) ) {
          $info{ $stock, "success" } = 0;
          $info{ $stock, "errormsg" } =
            "Error retrieving quote for $stock. No data returned";
          next;
        }

        ### [<now>] JSON: $json

        $json_decoded = decode_json $json;
        ### [<now>] JSON Decoded: $json_decoded

        my $result_array;
        if ($json_decoded->{'props'}{'pageProps'}{'data'}{'snapshot'}{'instrument'}) {
            $result_array = [ $json_decoded->{'props'}{'pageProps'}{'data'}{'snapshot'}{'instrument'} ];
        } else {
            $result_array = $json_decoded->{'props'}{'pageProps'}{'facets'}[0]{'results'};
        }
        ### [<now>] Result Array: $result_array
        my $item;
        foreach $item ( @$result_array ) {
          ### [<now>] Item: $item
          if ( ($item->{'symbol'} && $item->{'symbol'} eq $stock)
             or ($item->{'wkn'} && $item->{'wkn'} eq $stock)
             or ($item->{'isin'} && $item->{'isin'} eq $stock)
             ) {
            last;
          }
        }

        # By default set URL to first in array
        # For US stocks, the symbol may not match stock
        $item ||= $result_array->[0];
        map { $info{ $stock, $_ } = $item->{$_} } qw(symbol wkn isin);
        $url = $item->{'urls'}{'WEBSITE'};

        unless ( $url ) {
          $info{ $stock, "success" } = 0;
          $info{ $stock, "errormsg" } = "No data found for $stock.";
          next;
        }

        ### [<now>] New URL: $url
        $reply = $ua->request( GET $url);

        $code    = $reply->code;
        $desc    = HTTP::Status::status_message($code);
        $headers = $reply->headers_as_string;
        $body    = $reply->decoded_content;

        unless ( $code == 200 ) {
          $info{ $stock, "success" } = 0;
          $info{ $stock, "errormsg" } = "Error accessing $url ($desc).";
          next;
        }

        # Create HTML::TreeBuilder object from 2nd URL's body
        $tree = HTML::TreeBuilder->new;
        unless ($tree->parse($body)) {
          $info{ $stock, "success" } = 0;
          $info{ $stock, "errormsg" } = "Error parsing HTML from $url.";
          next;
        }
        $tree->eof;

        unless ( $json = encode_utf8(($tree->look_down(_tag => 'script', id => '__NEXT_DATA__', type => 'application/json')->content_list())[0]) ) {
          $info{ $stock, "success" } = 0;
          $info{ $stock, "errormsg" } =
            "Error retrieving quote for $stock. No data returned";
          next;
        }

        ### [<now>] 2nd JSON: $json

        eval {$json_decoded = decode_json encode_utf8 $json};
        if($@) {
          $info{ $stock, 'success' } = 0;
          $info{ $stock, 'errormsg' } = $@;
          next;
        }

        my $exchange = exists $quoter->{module_specific_data}->{onvista}->{EXCHANGE} ?
                              $quoter->{module_specific_data}->{onvista}->{EXCHANGE} : undef;

        my $markets = $json_decoded->{'props'}{'pageProps'}{'data'}{'snapshot'}{'quoteList'}{'list'};
        $info{ $stock, 'exchanges' } = [ map { $_->{'market'}{'name'} } @$markets ];

        my $json_quote;
        if ($exchange) {
          ($json_quote) = grep { $_->{'market'}{'name'} eq $exchange
                              or $_->{'market'}{'codeExchange'} eq $exchange
                               } @$markets;
          unless($json_quote) {
            $info{ $stock, "success" } = 0;
            $info{ $stock, "errormsg" } =
                "Error retrieving quote for $stock. No data returned for $exchange";
            next;
          }
        } else {
          $json_quote = $json_decoded->{'props'}{'pageProps'}{'data'}{'snapshot'}{'quote'};
        }

        ### [<now>] 2nd JSON Decoded: $json_decoded

        $info{ $stock, "success" } = 1;
        $info{ $stock, 'method' } = 'onvista';
        $info{ $stock, 'source' } = $url;
        $info{ $stock, 'name' } = $json_decoded->{'props'}{'pageProps'}{'data'}{'snapshot'}{'instrument'}{'name'};

        map { $info{ $stock, $_ } = $json_quote->{$_} } qw(open high low last volume ask bid);
        $info{ $stock, 'price' } = $json_quote->{'last'};
        $info{ $stock, 'currency' } = $json_quote->{'isoCurrency'};
        $info{ $stock, 'exchange' } = $json_quote->{'market'}{'name'};
        $info{ $stock, 'close' } = $json_quote->{'previousLast'};
        $info{ $stock, 'change' } = $json_quote->{'performance'};
        $info{ $stock, 'p_change' } = $json_quote->{'performancePct'};
        $quoter->store_date(\%info, $stock, {isodate => substr $json_quote->{'datetimeLast'}, 0, 10});

        #$info{ $stock, 'time' } = substr $date, 11, 5; # UTC
        my $utc_timestamp = str2time($json_quote->{'datetimeLast'});
        $info{ $stock, 'time' } = strftime("%H:%M", localtime($utc_timestamp)); # local time zone
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

  } # end foreach stock

  return wantarray() ? %info : \%info;
  return \%info;

} # end onvista subroutine

1;

__END__

=head1 NAME

Finance::Quote::OnVista - Obtain quotes from Frankfurt Stock Exchange.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;
    or
    $q = Finance::Quote->new("OnVista", "onvista" => { "EXCHANGE" => "Xetra" });

    %info = $q->fetch("onvista", "sap");  # Only query onvista

    @exchanges = @{ $info{ "sap", "exchanges" } }; # List of available marketplaces

=head1 DESCRIPTION

This module fetches information from L<https://onvista.de/>.

This module is loaded by default on a Finance::Quote object. It's also possible
to load it explicitly by placing "onvista" in the argument list to
Finance::Quote->new().

This module provides "onvista" fetch methods. It was written
to replace a non-working Tradeville.pm module.

Information obtained by this module may be covered by Frankfurt Stock
Exchange terms and conditions.

=head1 EXCHANGE

https://onvista.de/ supports different market places. A default is not specified.

  "Xetra" alias "GER"
  "Tradegate" alias "GAT"
  "gettex" alias "TRO"
  "London Stock Exchange" alias "LSE"
  ... any many more ...

The EXCHANGE may be set by providing a module specific hash to
Finance::Quote->new as in the above example (optional).

=head1 LABELS RETURNED

The following labels are returned: 

=over

=item name

=item symbol

=item isin

=item wkn

=item open

=item close

=item high

=item low

=item price

=item bid

=item ask

=item date

=item time

=item currency

=item change

=item p_change

=item source

=back
