#!/usr/bin/perl -w

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

package Finance::Quote::DWS;

use strict;
use warnings;

use Web::Scraper;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

# VERSION

our @labels = qw/name date isodate last name currency/;

sub labels {
  return(dwsfunds => \@labels);
}

sub methods {
  return(dwsfunds => \&dwsfunds);
}

sub dwsfunds {
  my $quoter  = shift;
  my @symbols = @_;
  my $ua      = $quoter->user_agent();
  my %info;

  if (not exists $quoter->{DWS_CACHE}) {
    $quoter->{DWS_CACHE} = {};

    eval {
      my @headers = (
          'User-Agent'      => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 11_1_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.88 Safari/537.36',
          'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
          'Accept-Encoding' => 'gzip, deflate, br',
          'Accept-Language' => 'en-US,en;q=0.9'
          );

      my $url   = 'https://www.deami.de/dps/ff/prices.aspx';
      my $reply = $ua->get($url, @headers);

      ### reply : $reply

      my $processor = scraper {
        process '//*[@id="FundsFinder_ResultTable"]/tr', 'row[]' => scraper {
          process 'td', 'col[]' => scraper {
            process 'a', 'name' => 'TEXT';
            process ':not(a)', 'other' => ['HTML', sub{[split m|<br */>|, $_]}];
          };
      };
      };

      my $data = $processor->scrape($reply);

      ### data: $data

      # skip first row, which is the header
      for (my $i = 1; $i < @{$data->{row}}; $i++) {
        eval {
          my $name = $data->{row}->[$i]->{col}->[1]->{name};
          my $date = $data->{row}->[$i]->{col}->[2]->{other}->[0];
          my $last = $data->{row}->[$i]->{col}->[2]->{other}->[2];
          my $wkn  = $data->{row}->[$i]->{col}->[4]->{other}->[1];
          my $isin = $data->{row}->[$i]->{col}->[4]->{other}->[2];

          $last =~ s/,/./;

          my $info = {name => $name, date => $date, last => $last, wkn => $wkn, isin => $isin};

          $quoter->{DWS_CACHE}->{$wkn}  = $info;
          $quoter->{DWS_CACHE}->{$isin} = $info;
        };
      }
    };
  }

  ### DWS_CACHE : $quoter->{DWS_CACHE}

  foreach my $symbol (@_) {
    if (exists $quoter->{DWS_CACHE}->{$symbol}) {
      $info{$symbol, 'name'}     = $quoter->{DWS_CACHE}->{$symbol}->{name};
      $info{$symbol, 'last'}     = $quoter->{DWS_CACHE}->{$symbol}->{last};
      $info{$symbol, 'wkn'}      = $quoter->{DWS_CACHE}->{$symbol}->{wkn};
      $info{$symbol, 'isin'}     = $quoter->{DWS_CACHE}->{$symbol}->{isin};
      $info{$symbol, 'currency'} = 'EUR';

      $quoter->store_date(\%info, $symbol, {eurodate => $quoter->{DWS_CACHE}->{$symbol}->{date}});

      $info{$symbol, 'success'} = 1;
    }
    else {
      $info{$symbol, 'success'}  = 0;
      $info{$symbol, 'errormsg'} = "Symbol $symbol not found.";
    }
  }
  
  return wantarray() ? %info : \%info;
}

1;

=head1 NAME

Finance::Quote::DWS - Obtain quotes from DWS (Deutsche Bank Gruppe)

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %fundinfo = $q->fetch("dwsfunds","847402", "DE0008474024", ...);

=head1 DESCRIPTION

This module obtains information about DWS managed funds. Query it with
German WKN and/or international ISIN symbols.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::DWS:
name, date, isodate, last, name, currency

=head1 TERMS & CONDITIONS

Information returned by this module is governed by DWS's terms
and conditions.

Finance::Quote is released under the GNU General Public License, version 2,
which explicitly carries a "No Warranty" clause.

=cut
