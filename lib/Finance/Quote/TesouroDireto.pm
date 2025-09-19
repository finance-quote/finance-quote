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
use Time::Piece;

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

# Sanitizes input from tesouro's csv (x.xxx,xx) to US values (xxxx.xx)
sub convert_price {
  $_ = shift;

  # Replaces ',' with '.' and removes the other "extra" characters
  tr/,. /./d ;

  return $_;
}

# Returns the bond name (concatenation of bond type and year).
# Some "special" bonds are paid in installments; the name of these
# bonds uses the year of the first installment, however the due date
# from the csv refers to the last one.
sub get_bond_name {
    my ($name, $date) = @_;

    my $year = substr($date, 6, 4);

    # Apply the conditional logic based on the value of $name.
    if ($name eq 'Tesouro Renda+ Aposentadoria Extra') {
        return "$name " . ($year - 19);
    } elsif ($name eq 'Tesouro Educa+') {
        return "$name " . ($year - 4);
    } else {
        # Otherwise, return a string of the name and the original year.
        return "$name $year";
    }
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

  my $url = "https://www.tesourotransparente.gov.br/ckan/dataset/df56aa42-484a-4a59-8184-7676580c81e3/resource/796d2059-14e9-44e3-80c9-2d9e30b405c1/download/precotaxatesourodireto.csv";
  my $response = $ua->request(GET $url);

  if ($response->is_success) {

    # process csv data
    foreach (split('\015?\012',$response->content)) {

      @q = $quoter->parse_csv_semicolon($_) or next;
      next unless (defined $q[0]);

      my $bond_name = get_bond_name($q[0], $q[1]);

      if (exists $fundhash{$bond_name})
      {
        my $t = Time::Piece->strptime($q[2], "%d/%m/%Y");
        next unless ($t->epoch > $fundhash{$bond_name});

        $fundhash{$bond_name} = $t->epoch;

        $info{$bond_name, "exchange"} = "Tesouro Direto";
        $info{$bond_name, "name"}     = $bond_name;
        $info{$bond_name, "symbol"}   = $bond_name;
        $info{$bond_name, "price"}    = convert_price($q[6]);
        $info{$bond_name, "last"}     = convert_price($q[6]);
        $quoter->store_date(\%info, $bond_name, {eurodate => $q[2]});
        $info{$bond_name, "method"}   = "tesouro_direto";
        $info{$bond_name, "currency"} = "BRL";
        $info{$bond_name, "success"}  = 1;
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
the dataset released by Secretaria do Tesouro Nacional on Tesouro 
Transparente under the Open Database License (ODbL):

https://www.tesourotransparente.gov.br/ckan/dataset/taxas-dos-titulos-ofertados-pelo-tesouro-direto

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::TesouroDireto:
exchange, name, symbol, date, price, last, method, currency.

=head1 SEE ALSO

=cut