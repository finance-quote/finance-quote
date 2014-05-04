# Copyright (C) 2013, Alan Berndt <alan@eatabrick.org>
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.

package Finance::Quote::Bitstamp;

use strict;
use JSON;

my @labels =
  qw/ask bid currency date exchange high last low method source success symbol time volume/;

sub methods {
  return map { $_ => \&bitstamp } qw(bitstamp bitcoin);
}

sub labels {
  return map { $_ => \@labels } qw(bitstamp bitcoin);
}

sub bitstamp {
  my ($self, @symbols) = @_;

  my %info;
  foreach my $symbol (@symbols) {
    next if exists $info{ $symbol, 'symbol' };

    $info{ $symbol, 'success' } = 0;
    $info{ $symbol, 'source' }  = 'bitstamp';
    $info{ $symbol, 'symbol' }  = $symbol;

    if ($symbol ne 'BTC') {
      $info{ $symbol, 'errormsg' } = 'Symbol not supported';
      next;
    }

    # Change UA because libwwwperl is blocked from bitstamp
    my $agent = $self->user_agent->agent;
    $self->user_agent->agent('Finance::Quote/' . $Finance::Quote::VERSION);
    my $r = $self->user_agent->get('https://www.bitstamp.net/api/ticker');
    $self->user_agent->agent($agent);

    if (not $r->is_success) {
      $info{ $symbol, 'errormsg' } = 'HTTP error: ' . $r->status_line;
      next;
    } elsif ($r->headers->content_type ne 'application/json') {
      $info{ $symbol, 'errormsg' } = 'API error, response not JSON';
      next;
    }

    my $ticker;
    eval { $ticker = decode_json($r->decoded_content); };
    if ($@) {
      $info{ $symbol, 'errormsg' } = 'Error parsing JSON: ' . $@;
      next;
    }

    $info{ $symbol, $_ } = $ticker->{$_} for qw( ask bid high last low volume );

    $info{ $symbol, 'currency' } = 'USD';
    $info{ $symbol, 'exchange' } = 'Bitstamp';
    $info{ $symbol, 'method' }   = 'bitstamp';
    $info{ $symbol, 'success' }  = 1;

    $self->store_date(\%info, $symbol, { epoch => $ticker->{timestamp} });
  }

  return wantarray() ? %info : \%info;
}

1;

=head1 NAME

Finance::Quote::Bitstamp - Obtain information from Bitstamp

=head1 SYNOPSIS

    use Finance::Quote;
    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch('bitstamp', 'BTC');

=head1 DESCRIPTION

This module fetches information from Bitstamp. The following symbols are
currently known:

=over

=item BTC: Bitcoin

=back

In addition, "bitcoin" method is provided in case failover to other exchanges
is desirable.

=head1 LABELS RETURNED

=over

=item ask: lowest asking price

=item bid: highest offer price

=item currency: currency of retrieved quote

=item date, time: time of last trade

=item exchange: always 'Bitstamp'

=item high: highest trade of the day

=item last: last trade price

=item low: lowest trade of the day

=item method: fetching method used

=item volume: daily volume of trades

=back

=cut
