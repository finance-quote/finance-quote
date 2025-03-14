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

package Finance::Quote::Tradegate;
use     Finance::Quote::Sinvestor;

use strict;
use warnings;

# VERSION

our $DISPLAY    = 'Tradegate';
our $FEATURES   = { map { $_ => $Finance::Quote::Sinvestor::FEATURES->{$_} }
                    grep { $_ ne "EXCHANGE" }
                    keys %$Finance::Quote::Sinvestor::FEATURES
                  };
our @LABELS     = grep { $_ ne "exchanges" } @Finance::Quote::Sinvestor::LABELS;
our $METHODHASH = {subroutine => \&tradegate,
                   display => $DISPLAY,
                   labels => \@LABELS,
                   features => $FEATURES};

sub labels {
  my %m = methodinfo(); return map {$_ => [@{$m{$_}{labels}}] } keys %m;
}

sub methodinfo {
    return (
        tradegate => $METHODHASH,
        europe    => $METHODHASH,
    );
}

sub methods {
  my %m = methodinfo(); return map {$_ => $m{$_}{subroutine} } keys %m;
}

sub tradegate {
  my $quoter  = shift;
  my $inst_id = exists $quoter->{module_specific_data}->{tradegate}->{INST_ID} ?
                       $quoter->{module_specific_data}->{tradegate}->{INST_ID} :
                       '0000057';

  return Finance::Quote->new('Sinvestor', 'sinvestor' => {INST_ID => $inst_id, EXCHANGE => "TDG"})->fetch("sinvestor", @_);
}

1;

=head1 NAME

Finance::Quote::Tradegate - Obtain quotes from S-Investor platform.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;
    or
    $q = Finance::Quote->new('Tradegate', 'tradegate' => {INST_ID => 'your institute id'});

    %info = Finance::Quote->fetch("Tradegate", "DE000ENAG999");  # Only query Tradegate
    %info = Finance::Quote->fetch("europe", "brd");     # Failover to other sources OK.

=head1 DESCRIPTION

This module fetches information from https://s-investor.de/, the investment platform
of the German Sparkasse banking group. It fetches share prices from tradegate,
a major German trading platform.

Suitable for shares and ETFs that are traded in Germany.

This module is loaded by default on a Finance::Quote object. It's also possible
to load it explicitly by placing "Tradegate" in the argument list to
Finance::Quote->new().

This module provides "Tradegate" and "europe" fetch methods.

Information obtained by this module may be covered by s-investor.de terms and
conditions.

=head1 INST_ID

https://s-investor.de/ supports different institute IDs. The default value "0000057" is
used (Krefeld) if no institute ID is provided. A list of institute IDs is provided here:
https://web.s-investor.de/app/webauswahl.jsp

The INST_ID may be set by providing a module specific hash to
Finance::Quote->new as in the above example (optional).

=head1 LABELS RETURNED

The following labels are returned:
currency
exchange
last
method
success
symbol
isin
date
time
volume
price
close
open
low
high
change
p_change
