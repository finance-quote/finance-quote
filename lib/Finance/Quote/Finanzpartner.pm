# Finance::Quote Perl module to retrieve quotes from Finanzpartner.de
#    Copyright (C) 2007  Jan Willamowius <jan@willamowius.de>
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

package Finance::Quote::Finanzpartner;

use strict;
use HTML::TableExtract;

use vars qw($VERSION);
$VERSION = '1.19';

my $FINANZPARTNER_URL = "http://www.finanzpartner.de/fi/";

sub methods {return (finanzpartner        => \&finanzpartner);}
sub labels { return (finanzpartner=>[qw/name date price last method/]); } # TODO

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
        tr/.,/,./ ;
	return $_;
}

sub finanzpartner
{
	my $quoter = shift;     # The Finance::Quote object.
	my @stocks = @_;
	my $ua = $quoter->user_agent();
	my %info;

	foreach my $stock (@stocks) {
		$ua->agent('Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1; .NET CLR 1.1.4322)');
		my $response = $ua->get($FINANZPARTNER_URL . $stock . '/');
		$info{$stock,"success"} = 0;
		if (!$response -> is_success()) {
			$info{$stock,"errormsg"} = "HTTP failure";
		} else {
			my $te = new HTML::TableExtract(depth => 0, count => 2);
			$te->parse($response->content);
			my $table = $te->first_table_found;

			if (trim($table->cell(1,0)) ne 'Fondsname:') {
				$info{$stock,"errormsg"} = "Couldn't parse website";
			} else {
				$info{$stock,"name"} = $table->cell(1,1);
				my $quote = $table->cell(6,1);
				my @part = split(/\s/, $quote);
				$info{$stock,"currency"} = $part[1];
				$part[2] =~ s/\(//g;
				$part[2] =~ s/\)//g;
				$quoter->store_date(\%info, $stock, {eurodate => $part[2]});
				$info{$stock,"price"} = convert_price(trim($part[0]));
				$info{$stock,"last"} = $info{$stock,"price"};
				$info{$stock,"success"} = 1;
				$info{$stock,"method"} = "finanzpartner";
				$info{$stock,"symbol"} = $stock;
			}
		}
	}
	return wantarray ? %info : \%info;
}

1;

=head1 NAME

Finance::Quote::Finanzpartner - Obtain quotes from Finanzpartner.de.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new("Finanzpartner");

    %info = $q->fetch("finanzpartner","LU0055732977");

=head1 DESCRIPTION

This module obtains quotes from Finanzpartner.de (http://www.finanzpartner.de) by WKN or ISIN.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::Finanzpartner:
name, date, price, last, method.

=head1 SEE ALSO

Finanzpartner, http://www.finanzpartner.de/

Finance::Quote;

=cut
