#!/usr/bin/perl -w
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
#
# $Id: $

package Finance::Quote::TesouroDireto;
require 5.10.1;

use strict;
use warnings;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use LWP::UserAgent;
use HTTP::Request::Common;
use JSON;

# VERSION

our $DISPLAY    = 'Brazilian Govt Bonds, tesouro_direto';
our $FEATURES   = {};
our @LABELS     = qw/exchange date isodate symbol name price last method currency/;
our $METHODHASH = {subroutine => \&tesouro,
                   display => $DISPLAY,
                   labels => \@LABELS,
                   features => $FEATURES};

sub methodinfo {
    return (
        tesouro_direto => $METHODHASH,
    );
}

sub methods {
    my %m = methodinfo(); return map {$_ => $m{$_}{subroutine} } keys %m;
}

sub labels {
    my %m = methodinfo(); return map {$_ => [@{$m{$_}{labels}}] } keys %m;
}

sub tesouro
{
  my $quoter = shift;
  my @funds = @_;
  return unless @funds;

  my $ua = $quoter->user_agent;

  my (%fundsymbol, %fundhash, @q, %info);

  # create hash of all funds requested
  foreach my $fund (@funds)
  {
      $fundhash{$fund} = 0;
  }

  my $url = "https://www.tesourodireto.com.br/json/br/com/b3/tesourodireto/service/api/treasurybondsinfo.json";
  $ua->agent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36');
  $ua->timeout(10);
  $ua->max_redirect(5);
  my $response = $ua->request(GET $url);

  if ($response->is_success) {

    my $data = decode_json($response->content)->{'response'};
    my $quote_date = substr($data->{'TrsrBondMkt'}{'qtnDtTm'},0,10);
    my @bounds_list = @{$data->{'TrsrBdTradgList'}};

    foreach(@bounds_list) {

      my $quote_name = $_->{'TrsrBd'}{'nm'};

      if (exists $fundhash{$quote_name})
      {
        $fundhash{$quote_name} = 1;

        $info{$quote_name, "exchange"} = "Tesouro Direto";
        $info{$quote_name, "name"}     = $quote_name;
        $info{$quote_name, "symbol"}   = $quote_name;
        $info{$quote_name, "price"}    = $_->{'TrsrBd'}{'untrRedVal'};
        $info{$quote_name, "last"}     = $_->{'TrsrBd'}{'untrRedVal'};
	      $quoter->store_date(\%info, $quote_name, {isodate => $quote_date});
        $info{$quote_name, "method"}   = "tesouro_direto";
        $info{$quote_name, "currency"} = "BRL";
        $info{$quote_name, "success"}  = 1;
      }
    }

    # check to make sure a value was returned for every fund requested
    foreach my $fund (keys %fundhash)
    {
      if ($fundhash{$fund} == 0)
      {
        $info{$fund, "success"}  = 0;
        $info{$fund, "errormsg"} = "No data returned";
      }
    }
  }
  else
  {
    foreach my $fund (@funds)
    {
      $info{$fund, "success"}  = 0;
      $info{$fund, "errormsg"} = "HTTP error";
    }
  }

  ### result: %info

  return wantarray() ? %info : \%info;
}


1;

=head1 NAME

Finance::Quote::TesouroDireto - Obtain quotes for Brazilian government bounds

=head1 SYNOPSIS

    use Finance::Quote;
    $q = Finance::Quote->new;

    %stockinfo = $q->fetch("tesouro_direto", "Tesouro IPCA+ 2045");

=head1 DESCRIPTION

This module obtains quotes for Brazilian government bounds, obtained from
https://www.tesourodireto.com.br/json/br/com/b3/tesourodireto/service/api/treasurybondsinfo.json

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::TesouroDireto:
exchange, name, symbol, date, price, last, method, currency.

=head1 SEE ALSO

=cut
