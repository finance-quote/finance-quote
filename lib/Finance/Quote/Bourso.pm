#!/usr/bin/perl -w
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@cpan.org>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#    Copyright (C) 2001, Rob Sessink <rob_ses@users.sourceforge.net>
#    Copyright (C) 2005, Morten Cools <morten@cools.no>
#    Copyright (C) 2006, Dominique Corbex <domcox@sourceforge.net>
#    Copyright (C) 2008, Bernard Fuentes <bernard.fuentes@gmail.com>
#    Copyright (C) 2009, Erik Colson <eco@ecocode.net>
#    Copyright (C) 2018, Jean-Marie Pacquet <jmpacquet@sourceforge.net>
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
# This code derived from Padzensky's work on package Finance::YahooQuote,
# but extends its capabilites to encompas a greater number of data sources.
#
#
# Changelog
#
# 2018-04-08  Jean-Marie Pacquet
#
#     * (1.49) Major site change (html 5)
#
# 2014-01-12  Arnaud Gardelein
#
#     *       changes on website
#
# 2009-04-12  Erik Colson
#
#     *       Major site change.
#
# 2008-11-09  Bernard Fuentes
#
#     *       changes on website
#
# 2006-12-26  Dominique Corbex <domcox@sourceforge.net>
#
#     * (1.4) changes on web site
#
# 2006-09-02  Dominique Corbex <domcox@sourceforge.net>
#
#     * (1.3) changes on web site
#
# 2006-06-28  Dominique Corbex <domcox@sourceforge.net>
#
#     * (1.2) changes on web site
#
# 2006-02-22  Dominique Corbex <domcox@sourceforge.net>
#
#     * (1.0) iniial release
#

require 5.005;

use strict;

package Finance::Quote::Bourso;

use vars qw( $Bourso_URL );

use HTTP::Request::Common;
use HTML::TreeBuilder;
use Encode qw(decode);
use JSON qw( decode_json );
use utf8;

# VERSION

my $Bourso_URL = 'https://www.boursorama.com/cours/';

sub methods {
    return (
             europe => \&bourso,
             france => \&bourso,
             bourso => \&bourso
    );
}

{
    my @labels =
        qw/name last date isodate p_change open high low close volume currency method exchange/;

    sub labels {
        return (
                 europe => \@labels,
                 france => \@labels,
                 bourso => \@labels
        );
    }
}

sub bourso_to_number {
    my $x = shift(@_);
    $x =~ s/\s//g;    # remove spaces etc in number
    return $x;
}

sub bourso {
    my $quoter = shift;
    my @stocks = @_;
    my $ua = $quoter->user_agent();
    my %info;

    foreach my $stock (@stocks) {
        eval {
          my $query = $Bourso_URL . $stock;
          my $reply = $ua->request(GET $query);
          my $body  = decode('UTF-8', $reply->content);
          my $root  = HTML::TreeBuilder->new_from_content($body);

          my $div   = $root->look_down(_tag => 'div',
                                       class => qr/^c-faceplate/);

          my $name  = $div->look_down(_tag => 'a', class => qr/^c-faceplate__company-link/)->as_text();
          $name =~ s/^\s+|\s+$//g;
          utf8::encode($name);

          my $currency = $div->look_down(_tag => 'span', class => qr/^c-faceplate__price-currency/)->as_text();
          $currency =~ s/^\s+|\s+$//g;

          my ($date, $last, $symbol, $low, $high, $close, $exchange, $volume, $net);

          if ($div->attr('data-ist-init')) {
              my $json  = JSON::decode_json($div->attr('data-ist-init'));
              $date     = $json->{'tradeDate'};
              $last     = $json->{'last'};
              $symbol   = $json->{'symbol'};
              $low      = $json->{'low'};
              $high     = $json->{'high'};
              $close    = $json->{'previousClose'};
              $exchange = $json->{'exchangeCode'};
              $volume   = $json->{'totalVolume'};
              $net      = $json->{'variation'};
          }
          else {
              # date captures more than the date, but the regular expression below extracts just the date
              $date    = $div->look_down(_tag => 'div', class => qr/^c-faceplate__real-time/)->as_text();
              $last    = $div->look_down(_tag => 'span', class => qr/^c-instrument c-instrument--last/)->as_text();
              $symbol  = $stock;
          }

          $info{$stock, 'symbol'}   = $symbol;
          $info{$stock, 'name'}     = $name;
          $info{$stock, 'currency'} = $currency;
          $info{$stock, 'last'}     = $last;
          $info{$stock, 'high'}     = $high if $high;
          $info{$stock, 'low'}      = $low if $low;
          $info{$stock, 'close'}    = $close if $close;
          $info{$stock, 'exchange'} = $exchange if $exchange;
          $info{$stock, 'volume'}   = $volume if $volume;
          $info{$stock, 'net'}      = $net if $net;

          # 2020-07-17 17:03:45
          $quoter->store_date(\%info, $stock, {isodate => $1}) if $date =~ m|([0-9]{4}-[0-9]{2}-[0-9]{2})|;

          # dd/mm/yyyy
          $quoter->store_date(\%info, $stock, {eurodate => $1}) if $date =~ m|([0-9]{2}/[0-9]{2}/[0-9]{4})|;

          $info{$stock, 'method' } = 'bourso'; 
          $info{$stock, 'success'} = 1;
        };
        if ($@) {
          $info{$stock, 'success'}  = 0;
          $info{$stock, 'errormsg'} = 'Failed to retrieve quote';
        }
    }

    return wantarray() ? %info : \%info;
    return \%info;
}

1;

=head1 NAME

Finance::Quote::Bourso - Obtain quotes from Boursorama.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("bourso","ml");  # Only query Bourso

=head1 DESCRIPTION

This module fetches information from the "Paris Stock Exchange",
https://www.boursorama.com. All stocks are available.

This module is loaded by default on a Finance::Quote object. It's
also possible to load it explicitly by placing "bourso" in the argument
list to Finance::Quote->new().

Information obtained by this module may be covered by www.boursorama.com
terms and conditions See https://www.boursorama.com/ for details.

=head1 LABELS RETURNED

The following labels will be returned by Finance::Quote::Bourso : name, last,
symbol, date, isodate, method, currency.  For some symbols, additional
information is available: exchange, high, low, close, net, volume.

=head1 SEE ALSO

Boursorama (french web site), https://www.boursorama.com

=cut
