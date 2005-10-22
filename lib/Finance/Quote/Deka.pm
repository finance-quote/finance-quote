# Finance::Quote Perl module to retrieve prices of Deka funds
#    Copyright (C) 2005  Knut Franke <Knut.Franke@gmx.de>
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
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

package Finance::Quote::Deka;

use strict;
use HTML::TableExtract;

use vars qw($VERSION);
$VERSION = '0.3';
my $DEKA_URL = "http://www.deka.de/de/produkte/fondsfinder/ergebnis_body_name.html?type=preise";

sub methods {return (deka        => \&deka);}
sub labels { return (deka=>[qw/name date price last method/]); }

# Trim leading and tailing whitespaces (also non-breakable whitespaces)
sub trim
{
    $_ = shift();
    s/^\s*//;
    s/\s*$//;
    s/&nbsp;//g;
    return $_;
}

sub deka
{
  my $quoter = shift;     # The Finance::Quote object.
  my @stocks = @_;
  my $ua = $quoter->user_agent();
  my %info;

  foreach my $stock (@stocks) {
    my $response = $ua->get($DEKA_URL . "&fcsd=" . $stock);
    $info{$stock,"success"} = 0;
    if (!$response -> is_success()) {
      $info{$stock,"errormsg"} = "HTTP failure";
    } else {
      my $te = HTML::TableExtract->new;
      $te->parse($response->content);
      if ($te->table_state(0,0) && $te->table_state(1,0)) {
	my $row = ($te->table_state(0,0)->rows)[1];
	$info{$stock,"name"} = $$row[4];
	$info{$stock,"currency"} = $$row[6];
	$quoter->store_date(\%info, $stock, {eurodate => $$row[12]});
	my $prices = ($te->table_state(1,0)->rows)[0];
	$info{$stock,"price"} = trim($$prices[0]);
	$info{$stock,"last"} = trim($$prices[2]);
	$info{$stock,"success"} = 1;
	$info{$stock,"method"} = "deka";
	$info{$stock,"symbol"} = $stock;
      } else {
	$info{$stock,"errormsg"} = "Couldn't parse deka website";
      }
    }
  }
  return wantarray ? %info : \%info;
}

1;

=head1 NAME

Finance::Quote::Deka - Obtain fonds quotes from DekaBank.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new("Deka");

    %info = Finance::Quote->fetch("deka","DE0008474511");

=head1 DESCRIPTION

This module obtains fund prices from DekaBank,
http://www.deka.de/. Deka website supports retrieval by name, WKN or ISIN.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::Deka:
name, date, price, last, method.

=head1 SEE ALSO

DekaBank, http://www.deka.de/

Finance::Quote;

=cut
