#    Finance::Quote Perl module to retrieve mutual fund's prices from 
#    www.mbank.pl
#    Copyright (C) 2009  michal.guminiak@gmail.com
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

package Finance::Quote::mBankMutualFunds;

use HTML::TableExtract;
use utf8;
use strict;

use vars qw($VERSION);
$VERSION = '0.1';
my $MBANK_URL="http://www.mbank.pl/indywidualny/inwestycje/sfi/notowania/tab3.pl";

sub methods {return (mbank        => \&mbank);}
sub labels { return (mbank => [qw/name date price last method/]); }

sub mbank
{
	my $quoter = shift;     # The Finance::Quote object.
	my @stocks = @_;
	my $ua = $quoter->user_agent();
	$ua->agent('Mozilla 6.1 (Gecko)');
	my %info;

	my $request = HTTP::Request->new(GET => $MBANK_URL);
	my $response = $ua->request($request);
	foreach my $stock (@stocks) {
		if (!$response -> is_success()) {
			$info{$stock,"success"} = 0;
			$info{$stock,"errormsg"} = "HTTP failure";
			next;
		} else {
			my $html=$response->content;
		        $html=~m!<input type=text size=12 name=dat value=\"(\d{4})-(\d{2})-(\d{2})\">!;
			my ($rok,$miesiac,$dzien)=($1,$2,$3);
			my $te = new HTML::TableExtract( count => 1, keep_html => 1 );
			$te->parse($response->content);

			foreach my $ts ($te->table_states) {
				foreach my $row ($ts->rows) {
					$row->[0] =~ s/.*\.\.\/fi\.html\?(\S{4}).*/$1/;
					if ($row->[0] eq $stock) {
						$info{$stock, "method"} = "mbank";
						$info{$stock, "name"} = $row->[0];
						$info{$stock, "symbol"} = $stock;
						$info{$stock, "currency"} = "PLN";
						$info{$stock, "source"} = $MBANK_URL;
						$row->[2] =~ s/,/\./;
						$info{$stock, "nav"} = $row->[2];
						$quoter->store_date(\%info, $stock, {year =>$rok, month => $miesiac, day => $dzien});
						$info{$stock, "success"} = 1;
					}
				}
			}
		}
	}
	return wantarray ? %info : \%info;
}

1;

=head1 NAME

Finance::Quote::mBankMutualFunds - Obtain mutual fund's quotes from www.mBank.pl

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new("mbank");

    %info = Finance::Quote->fetch("mbank","SNW");

=head1 DESCRIPTION

This module obtains mutual fund quotes from mBank webpage,

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::mBankMutualFunds:
name, date, symbol, nav, currency, method.

=head1 SEE ALSO

http://mBank.pl

Finance::Quote;

=cut
