#!/usr/bin/perl -w

# Copyright (C) 2023, Stephan Gambke <s7eph4n@gmail.com>

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301, USA

require 5.005;

use strict;
use warnings;

package Finance::Quote::Consorsbank;

use LWP::UserAgent;
use JSON qw( decode_json );
use Date::Parse qw(str2time);
use POSIX qw(strftime);
use Encode qw(encode_utf8);

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';
use if DEBUG, 'Data::Dumper';

# VERSION

my $CONSORS_URL = 'https://www.consorsbank.de/web-financialinfo-service/api/marketdata/stocks?';
my $CONSORS_SOURCE_BASE_URL = 'https://www.consorsbank.de/web/Wertpapier/';

our $DISPLAY    = 'Consorsbank - Consorsbank API';
our $FEATURES   = { 'EXCHANGE' => 'select market place (i.e. "gettex", "Xetra", "Tradegate")' };

    # Correspondence of FQ labels to Consorsbank API fields

    # success                            Did the stock successfully return information? (true/false)
    # errormsg    Info.Errors.ERROR_MESSAGE  If success is false, this field may contain the reason why.
    # symbol      Info.ID.SYMBOL         ticker symbol
    # wkn         Info.ID.WKN            WKN
    # symbol      Info.ID.ISIN           ISIN
    # name        BasicV1.NAME_SECURITY  Company or Mutual Fund Name
    # method      'consorsbank'          The module (as could be passed to fetch) which found this information.
    # source                             Source URL, either general website or direct human-readable deep link
    # exchange    CONSORS_EXCHANGE_NAME  The exchange the information was obtained from.
    # currency    ISO_CURRENCY           ISO currency code

    # ask         ASK                    Ask
    # avg_vol                            Average Daily Vol
    # bid         BID                    Bid
    # cap                                Market Capitalization
    # close       PREVIOUS_LAST          Previous Close
    # date        DATETIME_PRICE         Last Trade Date  (MM/DD/YY format)
    # day_range   HIGH, LOW              Day's Range
    # div                                Dividend per Share
    # div_date                           Dividend Pay Date
    # div_yield                          Dividend Yield
    # eps                                Earnings per Share
    # ex_div                             Ex-Dividend Date.
    # high        HIGH                   Highest trade today
    # last        PRICE                  Last Price
    # low         LOW                    Lowest trade today
    # nav                                Net Asset Value
    # net         PERFORMANCE            Net Change
    # open        FIRST                  Today's Open
    # p_change    PERFORMANCE_PCT        Percent Change from previous day's close
    # pe                                 P/E Ratio
    # time        DATETIME_PRICE         Last Trade Time
    # type                               The type of equity returned
    # volume      TOTAL_VOLUME           Volume
    # year_range  HIGH_PRICE_1_YEAR - LOW_PRICE_1_YEAR   52-Week Range
    # yield                              Yield (usually 30 day avg)

our @LABELS = qw/
        symbol wkn isin
        name
        method
        source
        exchange
        exchanges
        currency
        ask
        bid
        date
        day_range
        high
        last
        low
        net
        open
        close
        p_change
        volume
        year_range
    /;

our $METHODHASH = {subroutine => \&consorsbank,
                   display => $DISPLAY,
                   labels => \@LABELS,
                   features => $FEATURES};

sub methodinfo {
  return (
    consorsbank => $METHODHASH,
    europe      => $METHODHASH,
  );
}

sub labels {
  my %m = methodinfo(); return map {$_ => [@{$m{$_}{labels}}] } keys %m;
}

sub methods {
  my %m = methodinfo(); return map {$_ => $m{$_}{subroutine} } keys %m;
}

sub consorsbank {

    # a Finance::Quote object
    my Finance::Quote $quoter = shift;

    # a list of zero or more symbol names
    my @symbols = @_ or return;

    # user_agent() provides a ready-to-use LWP::UserAgent
    my $ua = $quoter->user_agent;

    my %info;

    my %mapping =       (# in QuotesV1, PriceV2, ExchangesV2
                        'exchange'  => 'CONSORS_EXCHANGE_NAME',
                        'currency'  => 'ISO_CURRENCY',  # also 'UNIT_PRICE' exists
                        'p_change'  => 'PERFORMANCE_PCT');

    my %map_price_v2 =  (# QuotesV1 & PriceV2 keys
                        'ask'       => 'ASK',
                        'bid'       => 'BID',
                        'close'     => 'PREVIOUS_LAST',
                        'open'      => 'FIRST',
                        'high'      => 'HIGH',
                        'last'      => 'PRICE',
                        'low'       => 'LOW',
                        'net'       => 'PERFORMANCE',
                        'volume'    => 'TOTAL_VOLUME');

    my %map_quotes_v1 = ( %map_price_v2,
                        # QuotesV1 keys
                        'year_low'  => 'LOW_PRICE_1_YEAR',
                        'year_high' => 'HIGH_PRICE_1_YEAR');

    my %map_exchanges_v2 = (# ExchangesV2 keys
                        'last'      => 'PRICE',
                        'ask'       => 'PRICE_ASK',
                        'bid'       => 'PRICE_BID');

    my $labels = $quoter->get_required_labels;
    $labels = \@LABELS unless(scalar(@$labels));

    my $require_quotes_v1 = grep { exists($map_quotes_v1{$_})
                               and not exists($map_exchanges_v2{$_})
                                 } @$labels;

    my $require_exchanges = grep { $_ eq 'exchanges' } @$labels;

    my $exchange = exists $quoter->{module_specific_data}->{consorsbank}->{EXCHANGE} ?
                          $quoter->{module_specific_data}->{consorsbank}->{EXCHANGE} : undef;

    if ($exchange and not $require_quotes_v1) {
        %mapping = (%mapping, %map_exchanges_v2);
    } else {
        %mapping = (%mapping, %map_quotes_v1);
    }

    my %map_basic_v1_id = (# BasicV1.ID keys
                         'symbol'       => 'SYMBOL',
                         'wkn'          => 'WKN',
                         'isin'         => 'ISIN',
                         'notation_id'  => 'ID_NOTATION');

    for my $symbol (@symbols) {

        ### $symbol

        $info{ $symbol, 'symbol' } = $symbol;
        $info{ $symbol, 'success'  } = 0;
        $info{ $symbol, 'errormsg' } = '';

        my $get_json = sub {
            my $query = shift;
            my $response = $ua->get($query);

            unless ($response->is_success) {
                $info{ $symbol, 'errormsg' } = "Unable to fetch data from the Consorsbank server for $symbol.  Error: " . $response->status_line;
                return;
            }

            unless ($response->header('content-type') =~ m|application/json|i) {
                $info{ $symbol, 'errormsg' } = "Invalid content-type from Consorsbank server for $symbol.  Expected: application/json, received: " . $response->header('content-type');
                return;
            }

            my $json = encode_utf8($response->content);

            ### [<here>] $json:
            ### $json

            my $data;
            eval { $data = JSON::decode_json($json) };

            if ($@) {
                $info{ $symbol, 'errormsg' } = "Failed to parse JSON data for $symbol.  Error: $@.";
                ### $@
                return;
            }

            ### [<here>] $data:
            ### $data

            if ( defined $data->[0]{'Info'}{'Errors'} ){
                ### API Error: $data->[0]{'Info'}{'Errors'}

                if ( $data->[0]{'Info'}{'Errors'}[0]{'ERROR_CODE'} eq 'IDMS' ){
                    $info{ $symbol, 'errormsg' } = "Invalid symbol: $symbol";
                } else {
                    $info{ $symbol, 'errormsg' } = $data->[0]{'Info'}{'Errors'}[0]{'ERROR_MESSAGE'}
                }
                return;
            }

            return $data;
        };

        my ($data, $quote);
        if ($exchange) {
            $data = &$get_json($CONSORS_URL . "id=$symbol&field=ExchangesV2&field=BasicV1") or next;
            $info{ $symbol, 'exchanges' } = [ map { $_->{'CONSORS_EXCHANGE_NAME'} } @{$data->[0]{'ExchangesV2'}} ];

            ($quote) = grep { $_->{'CONSORS_EXCHANGE_NAME'} eq $exchange
                           or $_->{'CONSORS_EXCHANGE_CODE'} eq '_' .$exchange
                            } @{$data->[0]{'ExchangesV2'}};
            unless($quote) {
                $info{ $symbol, 'errormsg' } = "Marketplace not found: $exchange";
                next;
            }
            if ($require_quotes_v1) {
                my ($id, $code) = ($quote->{'CONSORS_ID'}, $quote->{'CONSORS_EXCHANGE_CODE'});
                $data = &$get_json($CONSORS_URL . "id=$id&field=QuotesV1&field=BasicV1&rtExchangeCode=$code") or next;
                $quote = $data->[0]{'QuotesV1'}[0];
            }
        } else {
            if ($require_exchanges) {
                $data = &$get_json($CONSORS_URL . "id=$symbol&field=QuotesV1&field=BasicV1&field=ExchangesV2") or next;
                $info{ $symbol, 'exchanges' } = [ map { $_->{'CONSORS_EXCHANGE_NAME'} } @{$data->[0]{'ExchangesV2'}} ];
            } else {
                $data = &$get_json($CONSORS_URL . "id=$symbol&field=QuotesV1&field=BasicV1") or next;
            }
            $quote = $data->[0]{'QuotesV1'}[0];

            #$quote = $data->[0]{'PriceV2'};
        }

        ### [<here>] $symbol:
        ### $symbol

        while ((my $fqkey, my $cbkey) = each (%map_basic_v1_id)) {
            $info{ $symbol, $fqkey } = $data->[0]{'BasicV1'}{'ID'}{$cbkey}  if (defined $data->[0]{'BasicV1'}{'ID'}{$cbkey});
        }

        $info{ $symbol, 'name'        } = $data->[0]{'BasicV1'}{'NAME_SECURITY'} if (defined $data->[0]{'BasicV1'}{'NAME_SECURITY'});
        $info{ $symbol, 'method'      } = 'consorsbank';
        $info{ $symbol, 'source'      } = $CONSORS_SOURCE_BASE_URL . $data->[0]{'Info'}{'ID'};

        while ((my $fqkey, my $cbkey) = each (%mapping)) {
            $info{ $symbol, $fqkey } = $quote->{$cbkey} if (exists $quote->{ $cbkey } and defined $quote->{ $cbkey } );
        }

        # in QuotesV1, PriceV2, ExchangesV2
        if (defined($quote->{'DATETIME_PRICE'})) {
            my $utc_timestamp = str2time($quote->{'DATETIME_PRICE'});
            $info{ $symbol, 'time' } = strftime("%H:%M", localtime($utc_timestamp)); # local time zone
            $quoter->store_date(\%info, $symbol, {isodate => strftime("%Y-%m-%d", localtime($utc_timestamp))});
        }

        $info{ $symbol, 'day_range' } = $info{ $symbol, 'low' } . ' - ' . $info{ $symbol, 'high' }
            if (exists $info{ $symbol, 'low' } && exists $info{ $symbol, 'high' });

        $info{ $symbol, 'year_range' } = $info{ $symbol, 'year_low' } . ' - ' . $info{ $symbol, 'year_high' }
            if (exists $info{ $symbol, 'year_low' } && exists $info{ $symbol, 'year_high' });

        unless (defined $info{ $symbol, 'last'} ) {
            $info{ $symbol, 'errormsg' } = "The server did not return a price for $symbol.";
            next;
        }

        $info{ $symbol, 'success'  } = 1;
    }

    ### [<here>] %info:
    ### %info

    return wantarray() ? %info : \%info;
}
1;
__END__

=head1 NAME

Finance::Quote::Consorsbank - Obtain quotes from Consorsbank.

=head1 SYNOPSIS

        use Finance::Quote;

        $q = Finance::Quote->new;
        or
        $q = Finance::Quote->new("Consorsbank", "consorsbank" => { "EXCHANGE" => "Xetra" });

        %stockinfo = $q->fetch("consorsbank","DE0007664005"); # Only query consorsbank using ISIN.
        %stockinfo = $q->fetch("consorsbank","766400");       # Only query consorsbank using WKN.
        %stockinfo = $q->fetch("europe","DE0007664005");      # Failover to other sources OK.

        @exchanges = @{ $info{ "DE0007664005", "exchanges" } }; # List of available marketplaces

=head1 DESCRIPTION

This module obtains information from Consorsbank (https://www.consorsbank.de).

It accepts ISIN or German WKN as requested symbol.

This module is loaded by default on a Finance::Quote object.  It's
also possible to load it explicitly by placing "Consorsbank" in the argument
list to Finance::Quote->new().

This module provides both the "consorsbank" and "europe" fetch methods.
Please use the "europe" fetch method if you wish to have failover with other
sources for European stock exchanges. Using the "consorsbank" method will
guarantee that your information only comes from the Consorsbank service.

=head1 EXCHANGE

https://www.consorsbank.de/ supports different market places. A default is not specified.

  "Xetra" alias "GER"
  "Tradegate" alias "GAT"
  "gettex" alias "TRO"
  "Berlin" alias "BER"
  ... any many more ...

The EXCHANGE may be set by providing a module specific hash to
Finance::Quote->new as in the above example (optional).

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::Consorsbank:

symbol, wkn, isin, name, method, source, exchange, exchanges, currency,
ask, bid, date, day_range, high, last, low, net, open, close,
p_change, volume, year_range

=cut
