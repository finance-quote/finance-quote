#
# Copyright (C) 2012, Christopher Hill
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
#
# $Id: $
#

package Finance::Quote::MorningstarJP;
require 5.006;

use strict;
use warnings;
use base 'Exporter';
use Date::Calc qw(Add_Delta_Days Today);

use vars qw($VERSION $MORNINGSTAR_JP_URL);

our @EXPORT_OK = qw(morningstarjp methods labels);
$VERSION = '1.20' ;

# NAV information (basis price)
$MORNINGSTAR_JP_URL =
  ('http://www.morningstar.co.jp/FundData/DownloadStdYmd.do?fnc=');

sub methods { return ( morningstarjp => \&morningstarjp ); }
sub labels  { return ( morningstarjp => [qw/symbol date nav/] ); }

sub morningstarjp
{
  my @symbols = @_;
  my $quoter  = shift;

  my (
       $ua,    $response, %info,   $date,    $nav,   $year,
       $month, $day,      $fmyear, $fmmonth, $fmday, @data
  );

  $ua = $quoter->user_agent;

# Iterate over each symbol as site only permits query by single security
  foreach my $symbol (@symbols)
  {

    # Search upto and including today
    ( $year, $month, $day ) = Today();

    # Starting from 10 days prior (to cover any recent holiday gaps)
    ( $fmyear, $fmmonth, $fmday ) = Add_Delta_Days( $year, $month, $day, -10 );

    # Query the server via a POST request
    $response = $ua->post(
      $MORNINGSTAR_JP_URL . $symbol,
      [
        selectStdYearFrom  => $fmyear,
        selectStdMonthFrom => $fmmonth,
        selectStdDayFrom   => $fmday,
        selectStdYearTo    => $year,
        selectStdMonthTo   => $month,
        selectStdDayTo     => $day,
        base => '0'  # 0 is daily, 1 is week ends (Friday), 2 is month ends only
      ],
    );

    # Check response, CSV data is in an octet-stream
    if (    $response->is_success
         && $response->content_type eq 'application/octet-stream' )
    {

      # Parse...
      # First row (in Shift-JIS) is fixed.  It means "date","basis price"
      #   日付,基準価額
      # Subsequent rows are in ascending chronological order
      #   date(yyyymmdd),nav
      #
      # Split the data on CRLF or LF boundaries
      @data = split( '\015?\012', $response->content );

      # We only care about the final row as that has the most recent data
      ( $date, $nav ) = $quoter->parse_csv( $data[-1] );

      # Store the retrieved data into the hash
      ( $year, $month, $day ) = ( $date =~ m/(\d{4})(\d{2})(\d{2})/ );
      $quoter->store_date( \%info, $symbol,
                           { year => $year, month => $month, day => $day } );
      $info{ $symbol, 'currency' } = 'JPY';
      $info{ $symbol, 'method' }   = 'MorningstarJP';
      $info{ $symbol, 'name' }     = $symbol;
      $info{ $symbol, 'nav' }      = $nav;
      $info{ $symbol, 'success' }  = 1;
      $info{ $symbol, 'symbol' }   = $symbol;
    } elsif (    $response->is_success
              && $response->content_type eq 'text/html' )
    {

      # HTML response that means POST was invalid and/or rejected.
      $info{ $symbol, 'errormsg' } = 'Invalid search criteria';
      $info{ $symbol, 'success' }  = 0;
    } else
    {

      # Unknown error encountered.
      $info{ $symbol, 'errormsg' } = 'Search unavailable';
      $info{ $symbol, 'success' }  = 0;
    }
  }

  return wantarray() ? %info : \%info;
}

1;

__END__

=head1 NAME

Finance::Quote::MorningstarJP - Obtain price data from Morningstar (Japan).

=head1 VERSION

This documentation describes version 1.00 of MorningstarJP.pm, October 13, 2012.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = $q->fetch("morningstarjp", "2009100101");

=head1 DESCRIPTION

This module obtains information from Morningstar (Japan),
L<http://www.morningstar.co.jp/>.

Information returned by this module is governed by Morningstar
(Japan)'s terms and conditions.

=head1 FUND SYMBOLS

Use the numeric symbol shown in the URL on the "SnapShot" page
of the security of interest.

e.g. For L<http://www.morningstar.co.jp/FundData/SnapShot.do?fnc=2009100101>,
one would supply 2009100101 as the symbol argument on the fetch API call.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::MorningstarJP:
symbol, date, nav.

=head1 REQUIREMENTS

 Perl 5.006
 Date/Calc.pm
 Exporter.pm (included with Perl)

=head1 ACKNOWLEDGEMENTS

Inspired by other modules already present with Finance::Quote

=head1 AUTHOR

Christopher Hill

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2012, Christopher Hill.

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

Morningstar (Japan), L<http://www.morningstar.co.jp/>

=cut
