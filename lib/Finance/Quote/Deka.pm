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

require Crypt::SSLeay;

use vars qw($VERSION);
$VERSION = '1.18';
my $DEKA_URL = "https://www.deka.de/dn/useCases/fundsearch/UCFundsSearch.shtml?ACTION_FIELD=quickSearch";

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

# Convert number separators to US values
sub convert_price {
	$_ = shift;
	s/\./@/g;
	s/,/\./g;
	s/@/,/g;
	return $_;
}

sub deka
{
  my $quoter = shift;     # The Finance::Quote object.
  my @stocks = @_;
  my $ua = $quoter->user_agent();
  my %info;

  foreach my $stock (@stocks) {
    my $response = $ua->get($DEKA_URL . "&isin=" . $stock);
#    print $response->content, "\n";
    $info{$stock,"success"} = 0;
    if (!$response -> is_success()) {
      $info{$stock,"errormsg"} = "HTTP failure";
    } else {
      my @headers = [qw(Name ISIN Whg Datum)];
      my $te = new HTML::TableExtract(headers => @headers, slice_columns => 0);
      $te->parse($response->content);
      foreach my $ts ($te->table_states) {
#        foreach my $row ($ts->rows) {
#	  next if !defined $$row[0] || !defined $$row[1];
#	  print "Row: ", join('|', @$row), "\n";
#	}

        foreach my $row ($ts->rows) {
	  next if !defined $$row[0] || !defined $$row[1];
	  $info{$stock,"name"} = $$row[0];
	  $info{$stock,"currency"} = $$row[2];
	  $quoter->store_date(\%info, $stock, {eurodate => $$row[6]});
	  $info{$stock,"price"} = convert_price(trim($$row[4]));
	  $info{$stock,"last"} = $info{$stock,"price"};
	  $info{$stock,"success"} = 1;
	  $info{$stock,"method"} = "deka";
	  $info{$stock,"symbol"} = $stock;
        }
      }
      $info{$stock,"errormsg"} = "Couldn't parse deka website"
	  if ($info{$stock,"success"} == 0);
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
