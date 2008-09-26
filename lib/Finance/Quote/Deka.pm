# Finance::Quote Perl module to retrieve prices of Deka funds
#    Copyright (C) 2005,2007  Knut Franke <Knut.Franke@gmx.de>
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
$VERSION = '0.4';
my $DEKA_URL = "https://www.deka.de/decontent/dekaTrading.jsp?ACTION_FIELD=quickSearch&depot=fondsuche";

sub methods {return (deka        => \&deka);}
sub labels { return (deka=>[qw/price last method/]); }

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
      my $te = new HTML::TableExtract->new;
      $te->parse($response->content);
      foreach my $ts ($te->tables) {
         # check we have the right table and layout is as expected
         my @rows = $ts->rows;
         my @cols = $ts->columns;
         next unless $#rows >= 1;
         next unless $#cols >= 2;
         my $table_ok = 
            trim($ts->cell(0,2)) == "Anteilpreis Aktuell:"
            && trim($ts->cell(1,0)) == "W&auml;hrung:"
            && trim($ts->cell(1,2)) == "Anteilpreis Vortag:";
         next unless $table_ok;
         # extract the price information
         $info{$stock,"currency"} = $ts->cell(1,1);
         $info{$stock,"price"} = convert_price(trim($ts->cell(0,3)));
         $info{$stock,"last"} = convert_price(trim($ts->cell(1,3)));
         $info{$stock,"success"} = 1;
         $info{$stock,"method"} = "deka";
         $info{$stock,"symbol"} = $stock;
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

    %info = $q->fetch("deka","DE0008474511");

=head1 DESCRIPTION

This module obtains fund prices from DekaBank,
http://www.deka.de/. Deka website supports retrieval by name, WKN or ISIN.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::Deka:
price, last, method.

=head1 SEE ALSO

DekaBank, http://www.deka.de/

Finance::Quote;

=cut
