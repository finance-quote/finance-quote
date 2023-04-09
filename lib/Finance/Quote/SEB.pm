#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@cpan.org>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#    Copyright (C) 2000, Keith Refson <Keith.Refson@earth.ox.ac.uk>
#    Copyright (C) 2003, Tomas Carlsson <tc@tompa.nu>
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
#    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
#    02110-1301, USA
#
#
# This code was derived from the work on the packages Finance::Yahoo::*
#
package Finance::Quote::SEB;
require 5.004;

use strict;

use vars qw( $SEB_FUNDS_URL);

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use LWP::UserAgent;
use HTTP::Request::Common;
use utf8;

# VERSION
$SEB_FUNDS_URL = 'https://seb.se/pow/fmk/2100/Senaste_fondkurserna.TXT';

sub methods { return (seb_funds => \&seb_funds); }

{
  my @labels = qw/date isodate method source name currency price/;

  sub labels { return (seb_funds => \@labels); }
}

sub seb_funds {
  my $quoter  = shift;
  my @symbols = @_;

  return unless @symbols;
  my ($ua, $reply, $url, %funds);

  $url   = $SEB_FUNDS_URL;
  $ua    = $quoter->user_agent;
  $reply = $ua->request(GET $url);

  ### url : $url
  ### reply : $reply

  unless ($reply->is_success) {
    foreach my $symbol (@symbols) {
      $funds{$symbol, "success"}  = 0;
      $funds{$symbol, "errormsg"} = "HTTP failure";
    }
    return wantarray ? %funds : \%funds;
  }

  foreach my $line (split /\n/, $reply->content) {
    chomp($line);
    # Format:
    # 2003-08-11;SEB Aktiesparfond;5,605;387
    my ($date, $name, $price, $hmm) = split ';', $line;
    utf8::encode($name);
    if (grep {$_ eq $name} @symbols) {
      $price =~ s/,/\./; # change decimal point from , to .
      $funds{$name, 'symbol'}   = $name;
      $quoter->store_date(\%funds, $name, {isodate => $date});
      $funds{$name, 'method'}   = 'seb_funds';
      $funds{$name, 'source'}   = 'Finance::Quote::SEB';
      $funds{$name, 'name'}     = $name;
      $funds{$name, 'currency'} = 'SEK';
      $funds{$name, 'price'}    = $price;
      $funds{$name, 'success'}  = 1;
    }
  }

  # Check for undefined symbols
  foreach my $symbol (@symbols) {
    unless ($funds{$symbol, 'success'}) {
      $funds{$symbol, "success"}  = 0;
      $funds{$symbol, "errormsg"} = "Fund name not found";
    }
  }

  return %funds if wantarray;
  return \%funds;
}

1;

=head1 NAME

Finance::Quote::SEB - Obtain fund prices from www.seb.se

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %fundinfo = $q->fetch("seb_funds","fund name");

=head1 DESCRIPTION

This module obtains information about SEB fund prices from
www.seb.se.  The only available information source is "seb_funds"
and it will use www.seb.se.

=head1 FUND NAMES

Unfortunately there is no unique identifier for the fund names.
Therefore the complete fund name must be given, including spaces, case
is important.

Consult https://seb.se/bors-och-finans/fonder/fondkurslista
for all available funds.

Example "SEB Aktiesparfond"

=head1 LABELS RETURNED

Information available from SEB may include the following labels:
date method source name currency price. The prices are updated at the
end of each bank day.

=head1 SEE ALSO

SEB website - http://www.seb.se/

=cut
