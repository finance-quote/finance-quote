#!/usr/bin/perl -w
# vi: set ts=2 sw=2 noai expandtab ic showmode showmatch:  
#
#    Copyright (C) 2026, Kalpesh Patel <wrackguard+f_and_q@gmail.com>
#
#    This file is part of Finance::Quote.
#
#    Finance::Quote is free software: you can redistribute it and/or
#    modify it under the terms of the GNU General Public License as
#    published by the Free Software Foundation, either version 2 of
#    the License, or (at your option) any later version.
#
#    Finance::Quote is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#    General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with Finance::Quote.
#    If not, see <https://www.gnu.org/licenses/>.
#
# This code is derived from TSP.pm module.

package Finance::Quote::CoinMarketCap;

use strict;

use constant DEBUG => $ENV{DEBUG} || $ENV{CMC_DEBUG};
use if DEBUG, 'Smart::Comments', '###';

use vars qw( $CMC_URL $CMC_API_URL );

use LWP::UserAgent;
use HTTP::Request::Common;
use POSIX;
use JSON qw(decode_json);

# VERSION

# URLs of where to obtain information
$CMC_URL      = 'https://coinmarketcap.com/';
$CMC_API_URL = 'https://pro-api.coinmarketcap.com';

our $DISPLAY    = 'CMC - CoinMarketCap';
our @LABELS     = qw/name slug method symbol currency lastupdated isodate last source/;
our $METHODHASH = {subroutine => \&cmc,
                   display    => $DISPLAY,
                   labels     => \@LABELS};

sub parameters {
  return ('API_KEY');
}

sub new
{
  my $self = shift;
  my $class = ref($self) || $self;

  my $this = {};
  bless $this, $class;

  my $args = shift;

  ### CoinMarketCap->new args : $args

  # CoinMarketCap is permitted to use an environment variable for API key 
  # (for backwards compatibility).
  # New modules should use the API_KEY from args.

  $this->{API_KEY} = $ENV{'COINMARKETCAP_API_KEY'};
  $this->{API_KEY} = $args->{API_KEY} if (ref $args eq 'HASH') and (exists $args->{API_KEY});

  return $this;
}

sub methodinfo {
  return (
      cmc => $METHODHASH,
      CMC => $METHODHASH,
      coinmarketcap => $METHODHASH,
      crypto => $METHODHASH,
  );
}

sub labels {
  my %m = methodinfo();
  return map {$_ => [@{$m{$_}{labels}}] } keys %m;
}

sub methods {
  my %m = methodinfo();
  return map {$_ => $m{$_}{subroutine} } keys %m;
}

sub currency_fields {
    return qw/last/;
}

# ==============================================================================
sub cmc {
  my $quoter = shift;
  my @symbols = @_;
  my ( %info, $ua, $token, $reply, $url );

  return unless @symbols;

  $token = exists $quoter->{module_specific_data}->{cmc}->{API_KEY} ? 
                $quoter->{module_specific_data}->{cmc}->{API_KEY}        :
                $ENV{"COINMARKETCAP_API_KEY"};

  $ua = $quoter->user_agent;
  $ua->agent('Mozilla/5.0');
  $ua->default_header("Accept" => "application/json");

  my $public_uri = '';

  if (defined $token && length ($token) > 0 ) {
    $ua->default_header( "X-CMC_PRO_API_KEY" => $token );
  } else {
    $public_uri = '/public-api';
  }

# {
#   "data": [
#     {
#       "id": 1,
#       "name": "Bitcoin",
#       "symbol": "BTC",
#       "slug": "bitcoin",
#       "quotes": [
#         {
#           "symbol": "USD",
#           "price": 84722.98659312286
#         }
#       ]
#     }
#   ],
#   "status": {
#     "timestamp": "2026-09-27T19:58:29.169Z",
#     "error_code": "0",
#     "error_message": "",
#     "elapsed": 2,
#     "credit_count": 1
#   }
# }


  foreach my $symbol (@symbols) {

    # "https://pro-api.coinmarketcap.com/public-api/v2/simple/price?symbol=BTC,ETH,SOL&convert=USD"
    $url   = $CMC_API_URL . $public_uri . '/v2/simple/price?symbol=' . $symbol . '&convert=USD';
    $reply = $ua->request(GET $url);

    my $body = $reply->content;

    ### [<now>] url     : $url
    ### [<now>] reply   : $reply
    ### [<now>] success : $reply->is_success
    
    my $json_data = decode_json ($body);

    if (defined $json_data->{"data"}[0]) {
      $info{$symbol, 'success'} = 1;

      $info{$symbol, 'last'} = $json_data->{"data"}[0]->{"quotes"}[0]->{"price"};
      $info{$symbol, 'lastupdated'} = $json_data->{"status"}->{"timestamp"};
      $info{$symbol, 'name'} = $json_data->{"data"}[0]->{"name"};
      $info{$symbol, 'slug'} = $json_data->{"data"}[0]->{"slug"};

      $quoter->store_date(\%info, $symbol, {iso8601 => $json_data->{"status"}->{"timestamp"}});

      $info{$symbol, 'method'} = 'cmc';
      $info{$symbol, 'source'} = $CMC_URL;
      $info{$symbol, 'symbol'} = $json_data->{"data"}[0]->{"symbol"};
      $info{$symbol, 'currency'} = $json_data->{"data"}[0]->{"quotes"}[0]->{"symbol"};
    } else {
      $info{$symbol, "success"}  = 0;
      $info{$symbol, "errormsg"} = "CoinMarketCap fetch failed. No data for $symbol. ".$reply->status_line;
      
      ### Failure: $json_data->{"status"} 
    }

  }

  return %info if wantarray;
  return \%info;
}
1;

=head1 NAME

Finance::Quote::CoinMarketCap - Obtain fund prices for Crypto currencies.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = $q->fetch('CoinMarketCap','BTC');       #get quotes for Bitcoin

=head1 DESCRIPTION

This module fetches latest price for Crypto currencies from CoinMarketCap.

    https://CoinMarketCap.com

=head1 LABELS RETURNED

The following labels are returned by Finance::Quote::CMC :

    lastupdated               latest date, eg. "2026-09-27T19:58:29.169Z"
    isodate                   latest date, eg. "2010-02-21"
    last                      latest available price, eg. "16.1053"
    currency                  "USD"
    method                    "cmc"
    source                    https://CoinMarketCap.com
    symbol                    "BTC"
    name                      "Bitcoin"
    slug                      "bitcoin"

=cut
