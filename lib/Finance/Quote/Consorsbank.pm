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
use DateTime;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';
use if DEBUG, 'Data::Dumper';

# VERSION

my $CONSORS_URL = 'https://www.consorsbank.de/web-financialinfo-service/api/marketdata/stocks?';
my $CONSORS_SOURCE_BASE_URL = 'https://www.consorsbank.de/web/Wertpapier/';

sub methods {
    return (
        consorsbank => \&consorsbank,
        europe => \&consorsbank
    );
}

{
    # Correspondence of FQ labels to Consorsbank API fields

    # success                            Did the stock successfully return information? (true/false)
    # errormsg    Info.Errors.ERROR_MESSAGE  If success is false, this field may contain the reason why.
    # symbol      Info.ID                Lookup symbol (ISIN, WKN, ticker symbol)
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

    my @labels = qw/
        symbol
        name
        method
        source
        exchange
        currency
        ask
        bid
        close
        date
        day_range
        high
        last
        low
        net
        open
        p_change
        volume
        year_range
    /;

    # Function that lists the data items available from Consorsbank
    sub labels {
        return (
            consorsbank => \@labels,
            europe => \@labels);
    }
}

sub consorsbank {

    # a Finance::Quote object
    my Finance::Quote $quoter = shift;

    # a list of zero or more symbol names
    my @symbols = @_ or return;

    # user_agent() provides a ready-to-use LWP::UserAgent
    my $ua = $quoter->user_agent;

    my %info;

    for my $symbol (@symbols) {

        ### $symbol

        $info{ $symbol, 'symbol' } = $symbol;
        $info{ $symbol, 'success'  } = 1;
        $info{ $symbol, 'errormsg' } = '';

        my $query = $CONSORS_URL . "id=$symbol&field=QuotesV1&field=BasicV1";
        my $response = $ua->get($query);

        unless	($response->is_success) {
            $info{ $symbol, 'success' } = 0;
            $info{ $symbol, 'errormsg' } = "Unable to fetch data from the Consorsbank server for $symbol.  Error: " . $response->status_line;
            next;
        }

        unless ($response->header('content-type') =~ m|application/json|i) {
            $info{ $symbol, 'success' } = 0;
            $info{ $symbol, 'errormsg' } = "Invalid content-type from Consorsbank server for $symbol.  Expected: application/json, received: " . $response->header('content-type');
            next;
        }

        my $json = $response->content;


        ### [<here>] $json:
        ### $json

        my $data;
        eval { $data = JSON::decode_json($json) };

        if ($@) {
            $info{ $symbol, 'success' } = 0;
            $info{ $symbol, 'errormsg' } = "Failed to parse JSON data for $symbol.  Error: $@.";
            ### $@
            next;
        }

        ### [<here>] $data:
        ### $data

        if ( defined $data->[0]{'Info'}{'Errors'} ){
            ### API Error: $data->[0]{'Info'}{'Errors'}
            $info{ $symbol, 'success' } = 0;

            if ( $data->[0]{'Info'}{'Errors'}[0]{'ERROR_CODE'} eq 'IDMS' ){
                $info{ $symbol, 'errormsg' } = "Invalid symbol: $symbol";
            } else {
                $info{ $symbol, 'errormsg' } = $data->[0]{'Info'}{'Errors'}[0]{'ERROR_MESSAGE'}
            }
            next;
        }

        my $quote = $data->[0]{'QuotesV1'}[0];

        ### [<here>] $symbol:
        ### $symbol
        $info{ $symbol, 'symbol'     } = $data->[0]{'Info'}{'ID'}               if (defined $data->[0]{'Info'}{'ID'}) ;
        $info{ $symbol, 'name'       } = $data->[0]{'BasicV1'}{'NAME_SECURITY'} if (defined $data->[0]{'BasicV1'}{'NAME_SECURITY'});
        $info{ $symbol, 'method'     } = 'consorsbank';
        $info{ $symbol, 'source'     } = $CONSORS_SOURCE_BASE_URL . $data->[0]{'Info'}{'ID'};

        $info{ $symbol, 'day_range'  } = $quote->{'HIGH'} - $quote->{'LOW'}     if (defined $quote->{'HIGH'} && defined $quote->{'LOW'});

        $info{ $symbol, 'year_range' } = $quote->{'HIGH_PRICE_1_YEAR'} - $quote->{'LOW_PRICE_1_YEAR'}
                                                                                if (defined $quote->{'HIGH_PRICE_1_YEAR'} && defined $quote->{'LOW_PRICE_1_YEAR'});

        my %mapping = ('exchange' => 'CONSORS_EXCHANGE_NAME', 'currency' => 'ISO_CURRENCY', 'ask' => 'ASK',
            'bid' => 'BID', 'close' => 'PREVIOUS_LAST', 'high' => 'HIGH', 'last' => 'PRICE',
            'low' => 'LOW', 'net' => 'PERFORMANCE', 'open' => 'FIRST', 'p_change' => 'PERFORMANCE_PCT',
            'volume' => 'TOTAL_VOLUME' );

        while ((my $fqkey, my $cbkey) = each (%mapping)) {
            $info{ $symbol, $fqkey } = $quote->{$cbkey} if (defined $quote->{$cbkey});
        }

        $quote->{'DATETIME_PRICE'} = DateTime->now->iso8601 unless defined $quote->{'DATETIME_PRICE'};
        ($info{ $symbol, 'date' }, $info{ $symbol, 'time' }) = split /T/, $quote->{'DATETIME_PRICE'};
        $quoter->store_date(\%info, $symbol, { isodate => $info{ $symbol, 'date' } });

        unless (defined $info{ $symbol, 'last'} ) {
            $info{ $symbol, 'success' } = 0;
            $info{ $symbol, 'errormsg' } = "The server did not return a price for $symbol.";
            next
        }

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
	%stockinfo = $q->fetch("consorsbank","DE0007664005"); # Only query consorsbank using ISIN.
	%stockinfo = $q->fetch("consorsbank","766400");       # Only query consorsbank using WKN.
	%stockinfo = $q->fetch("europe","DE0007664005");      # Failover to other sources OK.

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

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::Consorsbank:

ask, bid, close, date, day_range, high, last, low, net, open, p_change, volume, year_range

=cut
