#
# Copyright (C) 2018, Diego Marcolungo
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

package Finance::Quote::Fondsweb;


use warnings;
use strict;

use HTTP::Request::Common;
use HTML::TreeBuilder::XPath;

# VERSION 

our $FONDSWEB_URL = "https://www.fondsweb.com/de/";

sub methods { return ( fondsweb => \&fondsweb ); }

{
	my @labels = qw/name isin date isodate year_range nav last currency source method type/;
	sub labels { return (fondsweb => \@labels); }
}

sub fondsweb {
	
	my $quoter = shift;
	my @symbols  = @_;
	my $te = HTML::TableExtract->new( depth => 0, count => 6 );
	my $tree = HTML::TreeBuilder::XPath->new;
	my %info;
	
	# Iterate over each symbol
	foreach my $symbol (@symbols) {
		my $url = $FONDSWEB_URL . $symbol;
		#~ debug_ua( $quoter->user_agent );	
		
		# The site check the user agent
		$quoter->user_agent->agent("Mozilla/5.0 (X11; Linux x86_64; rv:64.0) Gecko/20100101 Firefox/64.0");
		my $reply = $quoter->user_agent->request(GET $url);
		
		# Check response
		unless ($reply->is_success) {
			$info{ $symbol, "success" } = 0;
			$info{ $symbol, "errmsg" } = join ' ', $reply->code, $reply->message;
		} else {
			# Parse the HTML tree
			$tree->parse( $reply->decoded_content );
			
			# Find data using xpath
			# name
			my $name = $tree->findvalue( '//h1[@class="fw--h1 fw--fondsModule-head-content-headline"]');
			$info{ $symbol, 'name' } = $name;
			
			# isin
			my $isin_raw = $tree->findvalue( '//span[@class="text_bold"]');
			my @isin = $isin_raw =~ m/^(\w\w\d+)\w./;
			$info{ $symbol, 'isin' } = $isin[0];			
			
			# date, isodate
			my $raw_date = $tree->findvalue( '//i[@data-key="nav"]/..' );
			my @date = $raw_date =~ m/.(\d\d)\.(\d\d)\.(\d\d\d\d)./;
			$quoter->store_date(\%info, $symbol, {eurodate => "$date[0]/$date[1]/$date[2]"} );			
			
			# year_range, in this case use table extract
			$te->parse($reply->decoded_content);
			# the 6th table
			my $details = $te->table(0, 6);
			my $lastRowIndex = @{$details->rows} - 1;
			# extract data with re
			my @highest = $details->cell($lastRowIndex - 1, 1) =~ m/^(\d+),(\d+)\s.+/;
			my @lowest = $details->cell($lastRowIndex, 1) =~ m/^(\d+),(\d+)\s.+/;			
			$info{ $symbol, "year_range" } = join('.', @highest) . " - " . join('.', @lowest);
			
			# nav, last, currency
			my $raw_nav_currency = $tree->findvalue( '//div[@class="fw--fondDetail-price"]' );
			my @nav_currency = $raw_nav_currency =~ m/^(\d+),(\d+)\s(\w+)/;
			$info{ $symbol, 'nav' } = join('.', @nav_currency[0,1]);
			$info{ $symbol, 'last' } = $info{ $symbol, 'nav' };
			$info{ $symbol, 'currency' } = $nav_currency[-1];
			
			# Other metadata					
			$info{ $symbol, 'method' } = 'fondsweb';
			$info{ $symbol, "type" } = "fund";
			$info{ $symbol,	"success" } = 1;
		}
	}

	return wantarray ? %info : \%info;
}

__END__

=head1 NAME

Finance::Quote::Fondsweb - Obtain price data from Fondsweb (Germany)

=head1 VERSION

This documentation describes version 1.00 of Fondsweb.pm, December 28, 2018.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = $q->fetch("fondsweb", "LU0804734787");

=head1 DESCRIPTION

This module obtains information from Fondsweb (Germany),
L<https://www.fondsweb.com/>.

Information returned by this module is governed by Fondsweb
(Germany)'s terms and conditions.

=head1 FUND SYMBOLS

Use the ISIN number 

e.g. For L<https://www.fondsweb.com/de/LU0804734787>,
one would supply LU0804734787 as the symbol argument on the fetch API call.

=head1 LABELS RETURNED

The following labels are returned by Finance::Quote::Fondsweb:

- currency
- date
- isin
- isodate
- last
- method
- name
- nav
- type
- year_range

=head1 REQUIREMENTS

 Perl 5.012
 HTML::TableExtract
 HTML::TreeBuilder::XPath

=head1 ACKNOWLEDGEMENTS

Inspired by other modules already present with Finance::Quote

=head1 AUTHOR

Diego Marcolungo

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018, Diego Marcolungo.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=head1 DISCLAIMER

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

=head1 SEE ALSO

Fondsweb (Germany), L<https://www.fondsweb.com/>

=cut
