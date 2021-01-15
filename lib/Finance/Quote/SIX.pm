#!/usr/bin/perl -w

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

package Finance::Quote::SIX;

use strict;
use warnings;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use LWP::UserAgent;
use JSON qw( decode_json );
use String::Util qw(trim);
use Scalar::Util qw(looks_like_number);

# VERSION

our @labels = qw/last date isodate/;

sub labels {
  return ( six => \@labels );
}

sub methods {
  return ( six => \&six );
}

sub six {
  my $quoter  = shift;
  my @symbols = @_;
  my $ua      = $quoter->user_agent();
  my %info;

  foreach my $symbol (@_) {
    eval {
      # 1. Search for the security
      my $url      = 'https://www.six-group.com/fqs/snap.json?select=ValorId,PortalSegment,ProductLine&where=PortalSegment=EQ|BO|FU|EP|IN&pagesize=2&match=' . $symbol;
      my $reply    = $ua->get($url);
      my $search   = JSON::decode_json $reply->content;

      ### Search   : $url, $reply->code
      ### Search   : $search
      
      # 2. Get security metadata
      my $valorid  = $search->{rowData}->[0][0];
      die "$symbol not found" unless defined $valorid;

      $url         = 'https://www.six-group.com/fqs/ref.json?select=DividendEntitlementFlag,FirstTradingDate,LastTradingDate,ISIN,IssuerNameFull,IssuerNameShort,MarketDate,NominalCurrency,NominalValue,NumberInIssue,ProductLine,SecTypeDesc,ShortName,SmallestTradeableUnit,TitleSegment,TitleSegmentDesc,TradingBaseCurrency,ValorNumber,ValorSymbol&where=ValorId=' . $valorid;
      $reply       = $ua->get($url);
      my $metadata = JSON::decode_json $reply->content;
      
      ### Metadata : $url, $reply->code
      ### Metadata : $metadata

      my @metacols  = @{$metadata->{colNames}};
      my %metamap   = map {$metacols[$_] => $_} (0 .. $#metacols);
      my $metarow   = $metadata->{rowData}->[0];

      $info{$symbol, 'isin'}     = $metarow->[$metamap{ISIN}];
      $info{$symbol, 'name'}     = $metarow->[$metamap{IssuerNameFull}];
      $info{$symbol, 'currency'} = $metarow->[$metamap{NominalCurrency}];

      $quoter->store_date(\%info, $symbol, {isodate => $metarow->[$metamap{MarketDate}]});

      $url         = 'https://www.six-group.com/fqs/movie.json?select=AskPrice,AskVolume,BidPrice,BidVolume,ClosingDelta,ClosingPerformance,ClosingPrice,DailyHighPrice,DailyHighTime,DailyLowPrice,DailyLowTime,LatestTradeVolume,MarketMakers,MarketTime,MidSpread,OffBookTrades,OffBookTurnover,OffBookVolume,OnMarketTrades,OnMarketTurnover,OnMarketVolume,OpeningPrice,PreviousClosingPrice,SwissAtMidTrades,SwissAtMidTurnover,SwissAtMidVolume,TotalVolume,VWAP60Price,YearAgoPerformance,YearlyHighDate,YearlyHighPrice,YearlyLowDate,YearlyLowPrice,YearToDatePerformance,YieldToWorst&where=ValorId=' . $valorid;
      $reply       = $ua->get($url);
      my $data     = JSON::decode_json $reply->content;

      ### Data     : $url, $reply->code
      ### Data     : $data

      my @datacols  = @{$data->{colNames}};
      my %datamap   = map {$datacols[$_] => $_} (0 .. $#datacols);
      my $datarow   = $data->{rowData}->[0];

      $info{$symbol, 'ask'}     = $datarow->[$datamap{AskPrice}]       if $datarow->[$datamap{AskPrice}] and looks_like_number($datarow->[$datamap{AskPrice}]);
      $info{$symbol, 'close'}   = $datarow->[$datamap{ClosingPrice}]   if $datarow->[$datamap{ClosingPrice}];
      $info{$symbol, 'high'}    = $datarow->[$datamap{DailyHighPrice}] if $datarow->[$datamap{DailyHighPrice}];
      $info{$symbol, 'low'}     = $datarow->[$datamap{DailyLowPrice}]  if $datarow->[$datamap{DailyLowPrice}];
      $info{$symbol, 'open'}    = $datarow->[$datamap{OpeningPrice}]   if $datarow->[$datamap{OpeningPrice}];
      $info{$symbol, 'volume'}  = $datarow->[$datamap{TotalVolume}]    if $datarow->[$datamap{TotalVolume}];
      $info{$symbol, 'success'} = 1;
    };
    
    if ($@) {
      my $error = "SIX failed: $@";
      $info{$symbol, 'success'}  = 0;
      $info{$symbol, 'errormsg'} = trim($error);
    }
  }

  return wantarray() ? %info : \%info;
}

1;

=head1 NAME

Finance::Quote::SIX - Obtain quotes from the Swiss Stock Exchange

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch('six', 'NESN');

=head1 DESCRIPTION

This module fetches information from the Swiss Stock Exchange, 
https://www.six-group.com.

This module is loaded by default on a Finance::Quote object. It's also possible
to load it explicitly by placing 'SIX' in the argument list to
Finance::Quote->new().

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::SIX :
isin name currency date isodate ask close high low open volume success

=head1 TERMS & CONDITIONS

Use of www.six-group.com is governed by any terms & conditions of that site.

Finance::Quote is released under the GNU General Public License, version 2,
which explicitly carries a "No Warranty" clause.

=cut

