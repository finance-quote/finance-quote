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
#    Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
#    02111-1307, USA
#
package Finance::Quote::Currencies;

use strict;
use warnings;

use base 'Exporter';

our @EXPORT_OK = qw( known_currencies fetch_live_currencies );

our $VERSION = '1.0';

# =======================================================================
# methods used by Finance::Quote to import public functions
sub methods { return ( known_currencies      => \&known_currencies
                     , fetch_live_currencies => \&fetch_live_currencies
                     );
}

sub labels { return () };

# =======================================================================
# The current static currency list.
# This list is generated using get_live_
my %currencies = ( CAD => { name => "Canadian Dollar" }
                 , AUD => { name => "Australian Dollar" }
                 , EUR => { name => "Euro" }
                 );

# =======================================================================
# known_currencies (public function)
#
# This function returns the known currency list. This is based on the
# cached currency list in this module. Use fetch_live_currencies for the
# live list.
sub known_currencies {
  return \%currencies;
}

# =======================================================================
# fetch_live_currencies (public function)
#
# This function retrieved the live currency list from the Yahoo Finance
# website. This function should really only be used to test if the known
# currency list in this module is out of date.
sub fetch_live_currencies {
  return {};
}

1;

=head1 NAME

Finance::Quote::Currencies - List of currencies from Yahoo Finance

=head1 SYNOPSIS

    use Finance::Quote::Currencies;

    my $currencies = Finance::Quote::Currencies::known_currencies();

    # Grab the latest from Yahoo
    my $live_currencies = Finance::Quote::Currencies::fetch_live_currencies();

=head1 DESCRIPTION

This module provides a list of known currencies from Yahoo Finance.

TODO - mention the website

TODO - add method for getting latest data and checking if it is different
to the current data

=head1 SEE ALSO

Yahoo Finance website - TODO

=cut
