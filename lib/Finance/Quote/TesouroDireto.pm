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

# Sanitizes input from tesouro's csv (R$ x.xxx,xx) to US values (xxxx.xx)
sub convert_price {
  $_ = shift;

  # Replaces ',' with '.' and removes the other "extra" characters
  tr/,.R$ /./d ;

  return $_;
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

  my $url = "https://tesourodireto.com.br/documents/d/guest/rendimento-resgatar-csv?download=true";
  $ua->agent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36');
  $ua->timeout(10);
  $ua->max_redirect(5);
  my $response = $ua->request(GET $url);

  if ($response->is_success) {

    # process csv data
    foreach (split('\015?\012',$response->content)) {

      @q = $quoter->parse_csv_semicolon($_) or next;
      next unless (defined $q[0]);

      if (exists $fundhash{$q[0]})
      {
        $fundhash{$q[0]} = 1;

        $info{$q[0], "exchange"} = "Tesouro Direto";
        $info{$q[0], "name"}     = $q[0];
        $info{$q[0], "symbol"}   = $q[0];
        $info{$q[0], "price"}    = convert_price($q[2]);
        $info{$q[0], "last"}     = convert_price($q[2]);
        $quoter->store_date(\%info, $q[0], {today => 1});
        $info{$q[0], "method"}   = "tesouro_direto";
        $info{$q[0], "currency"} = "BRL";
        $info{$q[0], "success"}  = 1;
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
https://tesourodireto.com.br/documents/d/guest/rendimento-resgatar-csv?download=true

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::TesouroDireto:
exchange, name, symbol, date, price, last, method, currency.

=head1 SEE ALSO

=cut
