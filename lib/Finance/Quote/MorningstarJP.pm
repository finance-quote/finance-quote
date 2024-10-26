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

use strict;
use warnings;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use DateTime;
use IO::Uncompress::Gunzip;
use LWP::UserAgent;
use XML::Parser;

# VERSION

our $DISPLAY = 'Morningstar JP';
our @LABELS = qw/price name symbol currency method date isodate nav/;
our $METHODHASH = {subroutine => \&morningstarjp,
                   display => \$DISPLAY,
                   labels => \@LABELS};

sub methodinfo {
    return (
        morningstarjp => $METHODHASH,
    );
}

sub labels {
  my %m = methodinfo(); return map {$_ => [@{$m{$_}{labels}}] } keys %m;
}

sub methods {
  my %m = methodinfo(); return map {$_ => $m{$_}{subroutine} } keys %m;
}

our $MORNINGSTAR_JP_URL = 'https://www.wealthadvisor.co.jp/xml/';

sub morningstarjp
{
  my $quoter  = shift;
  my @symbols = @_;

  my ($ua, $response, %info);

  $ua = $quoter->user_agent;
  # Try to make the data transfer a bit smaller
  $ua->default_header('Accept-Encoding' => 'gzip, deflate, br');

  # Iterate over each symbol as site only permits query by single security
  foreach my $symbol (@symbols) {
      $response = $ua->get( $MORNINGSTAR_JP_URL . $symbol . ".xml");
      if ($response->is_success
          && $response->content_type eq 'text/xml') {

          my ($name,  $code, $date, $price, $nav);

          my $on_start = sub {
              my ($p, $el, %atts) = @_;
              if ($el eq "fund") {
                  ### assert: $atts{"name"}
                  ### assert: $atts{"code"}
                  $name = $atts{"name"};
                  $code = $atts{"code"};
              }
              elsif ($el eq "day") {
                  ### assert: $atts{"year"}
                  ### assert: $atts{"month"}
                  ### assert: $atts{"value"}
                  my $dt = DateTime->new(year => $atts{"year"},
                                         month => $atts{"month"},
                                         day => $atts{"value"});
                  my $px = $atts{"price"};
                  my $nv = $atts{"volume"};
                  if ($px && $nv) {
                      if (!defined($date)
                          || DateTime->compare($date, $dt) < 0) {
                          $date = $dt;
                          $price = $px;
                          $nav = $nv;
                      }
                  }
              }
          };

          my $xml = IO::Uncompress::Gunzip->new(\$response->content,
                                                Transparent => 1);
          ### assert: $xml

          # The XML itself is Shift_JIS encoded, but XML::Encoding doesn't
          # provide it, since in 1998 it was not clear which mapping to use,
          # see: https://github.com/steve-m-hay/XML-Encoding/blob/e48f2c7/maps/Japanese_Encodings.msg.
          # Based on the current registration https://www.iana.org/assignments/charset-reg/shift_jis
          # and the message above I guess it is x-sjis-unicode. But may be wrong and it can be
          # one of x-sjis-jisx0221, x-sjis-jdk117, or x-sjis-cp932.
          # The XML::Encoding need to be installed anyway.
          my $parser = XML::Parser->new(Handlers => {Start => \&$on_start},
                                        ProtocolEncoding => 'x-sjis-unicode');

          $parser->parse($xml);
          ### Extracted: $name, $code, $date->ymd, $price, $nav

          $quoter->store_date( \%info, $symbol,
                               { year => $date->year,
                                 month => $date->month,
                                 day => $date->day } );

          $info{ $symbol, 'currency' } = 'JPY';
          $info{ $symbol, 'method' }   = 'MorningstarJP';
          $info{ $symbol, 'name' }     = $name;
          $info{ $symbol, 'price' }    = $price;
          $info{ $symbol, 'nav' }      = $nav;
          $info{ $symbol, 'symbol' }   = $code;
          $info{ $symbol, 'success' }  = 1;
      }
      else {
          ### Error occurred: $symbol, $response
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
L<http://www.wealthadvisor.co.jp/>.

Information returned by this module is governed by Morningstar
(Japan)'s terms and conditions.

=head1 FUND SYMBOLS

Use the numeric symbol shown in the URL on the "SnapShot" page
of the security of interest.

e.g. For L<http://www.wealthadvisor.co.jp/FundData/SnapShot.do?fnc=2009100101>,
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

Morningstar (Japan), L<http://www.wealthadvisor.co.jp/>

=cut
