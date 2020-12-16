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

package Finance::Quote::Tradeville;

use strict;
use warnings;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use LWP::UserAgent;
use Web::Scraper;

# VERSION

my $TRADEVILLE_URL = 'https://tradeville.eu/actiuni/actiuni-';

sub methods { 
  return (romania    => \&tradeville,
          tradeville => \&tradeville,
          europe     => \&tradeville); 
}

our @labels = qw/symbol last close p_change volume open price/;

sub labels { 
  return (romania    => \@labels,
          tradeville => \@labels,
          europe     => \@labels); 
}

sub tradeville {
  my $quoter = shift;
  my @stocks = @_;
  my %info;
  my $ua = $quoter->user_agent();

  foreach my $stock (@stocks) {
    eval {
      my ($my_date, $my_last, $my_p_change, $my_volume, $my_open, $my_price);
      my $url = $TRADEVILLE_URL.join('', $stock);
      my $reply = $ua->get($url);
    
      ### [<now>] Fetched: $url
      my $data = scraper {
        process 'div.quotationTblLarge div', 'data[]' => ['TEXT', sub {s/\s//g}];
        process 'div.quotationTblLarge + br + p', 'date' => ['TEXT', sub{return $1 if ($_ =~ /([0-9]{1,2}.[0-9]{1,2}.[0-9]{4}, [0-9]{2}:[0-9]{2} [AP]M)/)}];
      };
      
      my $result = $data->scrape($reply);
      
      ### [<now>] result: $result
      my %table = @{$result->{data}};

      $info{$stock, 'success'}   = 1;
      $info{$stock, 'method'}    = 'tradeville';
      $info{$stock, 'symbol'}    = $stock;
      $info{$stock, 'last'}      = $table{'Ultimulpret' . uc($stock)};
      $info{$stock, 'p_change'}  = $table{'Variatie:'};
      $info{$stock, 'open'}      = $table{'Deschidere:'};
      $info{$stock, 'day_range'} = $table{'Maxim/Minim'};
      $info{$stock, 'volume'}    = $table{'Volum:'};
      $info{$stock, 'div_yield'} = $table{'Divid.yield:'};
      $info{$stock, 'currency'}  = $table{'Valuta:'};
      $info{$stock, 'cap'}       = $table{'MktCap:'};
      $info{$stock, 'exchange'}  = $table{'Piata:'};

      $quoter->store_date(\%info, $stock, {eurodate => $result->{date}});
    };
    if ($@) {
      $info{$stock, 'success'}  = 0;
      $info{$stock, 'errormsg'} = "Error retreiving $stock: $@";
    }
  }

  return wantarray() ? %info : \%info;
}

1;

=head1 NAME

Finance::Quote::BSERO - Obtain quotes from Bucharest Stock Exchange.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("tradeville", "tlv");  # Only query tradeville
    %info = Finance::Quote->fetch("romania", "brd");     # Failover to other sources OK.

=head1 DESCRIPTION

This module fetches information from https://tradeville.eu/, a leader in online
trading and pioneer of the Romanian capital market.

This module is loaded by default on a Finance::Quote object. It's also possible
to load it explicitly by placing "tradeville" in the argument list to
Finance::Quote->new().

This module provides "tradeville", "romania", and "europe" fetch methods.

Information obtained by this module may be covered by tradeville.eu terms and
conditions.

=head1 LABELS RETURNED

The following labels are returned: 
cap
currency
day_range
div_yield
exchange
last
method
open
p_change
success
symbol
volume

