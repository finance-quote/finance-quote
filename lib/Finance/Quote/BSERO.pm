#!/usr/bin/perl -w
#    This modules is based on the Finance::Quote::ASEGR module
#
#    The code has been modified by Andrei Cipu <strainu@strainu.ro> to be able to
#    retrieve stock information from the Bucharest Exchange in Romania.
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
require 5.005;

use strict;

package Finance::Quote::BSERO;

use vars qw( $BSERO_URL);

use LWP::UserAgent;
use HTTP::Request::Common;

our $VERSION = '1.47'; # VERSION

my $BSERO_URL = 'https://tradeville.eu/actiuni/actiuni-';

sub methods { return ( romania => \&bsero,
                       bsero => \&bsero,
                       europe => \&bsero); }
{
  my @labels = qw/name last date isodate p_change open high low close volume currency method exchange/;

  sub labels { return (romania => \@labels,
                       bsero => \@labels,
                       europe => \@labels); }
}

sub bsero {

  my $quoter = shift;
  my @stocks = @_;
  my (%info,$reply,$url);
  my($my_date,$my_last,$my_p_change,$my_volume,$my_high,$my_low,$my_open,$my_price);
  my $ua = $quoter->user_agent();

  $url = $BSERO_URL;

  foreach my $stocks (@stocks)
    {
      $reply = $ua->request(GET $url.join('', $stocks));

      if ($reply->is_success)
        {
          my $htmlstream	=	HTML::TokeParser->new(\$reply->content);

          my ($tag, $name, $var);
          while ( $tag = $htmlstream->get_tag('div') )
          {
            $var = $htmlstream->get_trimmed_text();

            if ( index($var, 'Ultimul pret') != -1 ) {
              $tag = $htmlstream->get_tag('div');
              if ( index($tag->[1]{'class'}, 'right') != -1 ) {
                $my_last = $htmlstream->get_trimmed_text();
                $my_last =~ tr/,//d;
              }

            } elsif ( $var eq 'Variatie:' ) {
              $tag = $htmlstream->get_tag('div');
              if ( index($tag->[1]{'class'}, 'right') != -1 ) {
                $my_p_change = $htmlstream->get_trimmed_text();
                substr($my_p_change, -1) = "";
              }

            } elsif ( $var eq 'Volum:' ) {
              $tag = $htmlstream->get_tag('div');
              if ( index($tag->[1]{'class'}, 'right') != -1 ) {
                $my_volume = $htmlstream->get_trimmed_text();
                $my_volume =~ tr/,//d;
              }

            } elsif ( $var eq 'Deschidere:' ) {
              $tag = $htmlstream->get_tag('div');
              if ( index($tag->[1]{'class'}, 'right') != -1 ) {
                $my_open = $htmlstream->get_trimmed_text();
                $my_open =~ tr/,//d;
              }

            } elsif ( $var eq 'Pret mediu:' ) {
              $tag = $htmlstream->get_tag('div');
              if ( index($tag->[1]{'class'}, 'right') != -1 ) {
                $my_price = $htmlstream->get_trimmed_text();
                $my_price =~ tr/,//d;
              }
            }
          }

          $info{$stocks, "success"}  =1;
          $info{$stocks, "exchange"} ="Bucharest Stock Exchange";
          $info{$stocks, "method"}   ="bsero";
          $info{$stocks, "symbol"}   =$stocks;
          $info{$stocks, "last"}     =$my_last;
          $info{$stocks, "close"}    =$my_last;
          $info{$stocks, "p_change"} =$my_p_change;
          $info{$stocks, "volume"}   =$my_volume;
          $info{$stocks, "open"}     =$my_open;
          $info{$stocks, "price"}    =$my_price;

          $quoter->store_date(\%info, $stocks, {eurodate => $my_date});

          $info{$stocks,"currency"} = "RON";

        } else {
          $info{$stocks, "success"}=0;
          $info{$stocks, "errormsg"}="Error retreiving $stocks ";
        }
    }
  return wantarray() ? %info : \%info;
  return \%info;
}

1;

=head1 NAME

Finance::Quote::BSERO - Obtain quotes from Bucharest Stock Exchange.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("bsero","tlv");  # Only query BSERO
    %info = Finance::Quote->fetch("romania","brd"); # Failover to other sources OK.

=head1 DESCRIPTION

This module fetches information from the "Bucharest Stock Exchange"
(Bursa de Valori Bucuresti), http://www.bvb.ro. All stocks are available.

This module is loaded by default on a Finance::Quote object. It's
also possible to load it explicitly by placing "BSERO" in the argument
list to Finance::Quote->new().

This module provides both the "bsero" and "romania" fetch methods.
Please use the "romania" fetch method if you wish to have failover
with future sources for Romanian stocks. Using the "bsero" method will
guarantee that your information only comes from the Bucharest Stock Exchange.

Information obtained by this module may be covered by www.bvb.go
terms and conditions See http://www.bvb.ro/ for details.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::BSERO :
name, last, date, p_change, open, high, low, close,
volume, currency, method, exchange.

=head1 SEE ALSO

Bucharest Stock Exchange, http://www.bvb.ro

=cut
