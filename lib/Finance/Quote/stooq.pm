#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@cpan.org>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#    Copyright (C) 2000, Keith Refson <Keith.Refson@earth.ox.ac.uk>
#    Copyright (C) 2003, Tomas Carlsson <tc@tompa.nu>
#    Copytight (C) 2010, Michal Fita <michal.fita@gmail.com>
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
#    Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
#    02111-1307, USA
#
#
# This code was derived from the work on the packages Finance::Yahoo::*
# This code was derived from the work on the packages Finance::SEB
#
package Finance::Quote::Stooq;
require 5.004;

use strict;

use vars qw($VERSION $STOOQ_STOCKS_URL);

use LWP::UserAgent;
use HTTP::Request::Common;
use utf8;

$VERSION = '0.10';
$STOOQ_STOCKS_URL = 'http://stooq.com/q/l/';

sub methods { return (stooq_stocks => \&stooq_stocks); }

{
  my @labels = qw/date isodate time method source name currency last open high low/;
	
  sub labels { return (stooq_stocks => \@labels); }
}

sub stooq_stocks {
  my $quoter  = shift;
  my @symbols = @_;

  return unless @symbols;
  my ($ua, $reply, $url, %stocks);

  $ua    = $quoter->user_agent;
  foreach my $symbol (@symbols) {
    # Nioch, nioch... stooq accepts only lower case tickers!
    $url   = $STOOQ_STOCKS_URL . '?s=' . lc $symbol;
    $reply = $ua->request(GET $url);
    unless ($reply->is_success) {
      $stocks{$symbol, "success"}  = 0;
      $stocks{$symbol, "errormsg"} = "HTTP failure";
      return wantarray ? %stocks : \%stocks;
    }

    my ($line) = split(/\n/, $reply->content, 1);
    chomp($line);
    # Format:
    # Trade Date, Name, Trade Time,Open, Max,Min,Price,Volume,Unknown
    # 20101229,"TAURONPE","142635",6.77,6.77,6.69,6.71,578233,0
    my ($date, $name, $time, $open, $high, $low, $last, $volume, $hmm) = split ',', $line;
    utf8::encode($name);
    #if (grep {$_ eq $name} @symbols) {
    unless ($date eq "N/A") {
      #$price =~ s/,/\./; # change decimal point from , to .
      $stocks{$symbol, 'symbol'}   = $symbol;
      my ($year, $month, $day) = ($date =~ /(\d{4})(\d{2})(\d{2})/);
      $quoter->store_date(\%stocks, $name, {year => $year, month => $month, day => $day});
      $stocks{$symbol, 'time'}     = ($_ = $time, s/(\d{2})(\d{2})(\d{2})/$1:$2:$3/, $_); 
      $stocks{$symbol, 'method'}   = 'stooq_stocks';
      $stocks{$symbol, 'source'}   = 'Finance::Quote::GPW';
      $stocks{$symbol, 'name'}     = ($_ = $name, s/[\"]//g, $_);
      $stocks{$symbol, 'currency'} = 'PLN'; 
      $stocks{$symbol, 'last'}     = $last;
      $stocks{$symbol, 'price'}    = $last;
      $stocks{$symbol, 'open'}     = $open;
      $stocks{$symbol, 'high'}     = $high;
      $stocks{$symbol, 'low'}      = $low;
      $stocks{$symbol, 'success'}  = 1;
    }
  }

  # Check for undefined symbols
  foreach my $symbol (@symbols) {
    unless ($stocks{$symbol, 'success'}) {
      $stocks{$symbol, "success"}  = 0;
      $stocks{$symbol, "errormsg"} = "Stock name not found";
    }
  }

  return %stocks if wantarray;
  return \%stocks;
}

1;

=head1 NAME

Finance::Quote::Stooq - Obtain prices of stocks traded on GPW from www.stooq.com

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %stockinfo = $q->fetch("stooq_stocks","tlt"); # the letter ticker

=head1 DESCRIPTION

This module obtains information about prices of stocks being trade on WARSAW
STOCK EXCHANGE market in Poland through popular stooq.com service, as currently
open method for accessing such data directly from GPW is not known.

=head1 STOCK NAMES

Every stock shares traded on Warsaw Stock Exchange has its own unique three
letter ticker.

For example:
"GPW" for Warsaw Stock Exchange itself,
"TPE" for Tauron Polska Energia,
"PZU" for Polski Zak³ad Ubezpieczeñ (most valuable equity is stocks on GPW).

=head1 LABELS RETURNED

Information available from GPW may include the following labels:
date time method source name currency price low high. The prices are available for most
recect closed session.

=head1 SEE ALSO

GPW website - http://www.gpw.pl/
STOOQ website - http://www.stooq.com/

=cut
