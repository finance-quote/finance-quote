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
package Finance::Quote::ASEGR;

use strict;
use warnings;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use LWP::UserAgent;
use Web::Scraper;
use Spreadsheet::XLSX;
use String::Util qw(trim);

# VERSION 

our @labels = qw/symbol date isodate close volume high low isin/;

our %labels = (symbol => ['symbol', 'trading symbol'],
               date   => ['date'],
               close  => ['price', 'current nominal value', 'closing price'],
               volume => ['volume'],
               high   => ['max'],
               low    => ['min'],
               isin   => ['isin']);

sub methods { 
  return ( greece => \&asegr,
	   asegr  => \&asegr,
	   europe => \&asegr);
}

sub labels { 
  return ( greece => \@labels,
	   asegr  => \@labels,
	   europe => \@labels);
}

our @sources = qw/statistics-end-of-day-securities 
                  statistics-end-of-day-etfs
                  statistics-end-of-day-bonds
                  statistics-end-of-day-warrants
                  statistics-end-of-day-derivatives
                  statistics-end-of-day-lending
                  statistics-end-of-day-indices/;

sub load_source {
  my $ua     = shift;
  my $table  = shift;
  my $source = shift;

  eval {
    my $url   = "https://www.athexgroup.gr/web/guest/$source";
    my $reply = $ua->get($url);

    ### Fetched : $url, $reply->code

    my $data = scraper {
      process 'div.portlet-content-container div.portlet-body table ~ p:last-child > a:first-child', 'link[]' => '@href';
    };
    
    my $result = $data->scrape($reply);
  
    foreach my $link (@{$result->{link}}) {
      $reply = $ua->get($link);

      ### Fetched : $link, $reply->code
      my $xlsx = $reply->content();
      my $io;
      open($io, '<', \$xlsx);

      my $workbook = Spreadsheet::XLSX->new($io);

      for my $worksheet ($workbook->worksheets()) {
        my ($row_min, $row_max) = $worksheet->row_range();
        my ($col_min, $col_max) = $worksheet->col_range();

        my %head = map {$_ => trim(lc($worksheet->get_cell($row_min, $_)->value()))} ($col_min .. $col_max);

        for my $row (($row_min+1) .. $row_max) {
          my $this = {};

          for my $col ($col_min .. $col_max) {

            my $cell = $worksheet->get_cell($row, $col);
            next unless $cell;

            $this->{$head{$col}} = trim($cell->value());
          }

          $table->{$this->{'symbol'}} = $this if exists $this->{'symbol'};
          $table->{$this->{'trading symbol'}} = $this if exists $this->{'trading symbol'};
        }
      }
    }
  };
  if ($@) {
    ### Error: $@
  }
}

sub asegr {
  my $quoter  = shift;
  my @symbols = @_;
  my $ua      = $quoter->user_agent();
  my @found;
  my %info;

  my %table;
  my $index = 0;

  while (@symbols and $index < @sources) {
    # Load the next source
    load_source($ua, \%table, $sources[$index++]);

    # Sift through @symbols
    push(@found, grep {exists $table{$_}} @symbols);
    @symbols = grep {not exists $table{$_}} @symbols;
  }

  ### Found     : @found
  ### Not found : @symbols

  foreach my $symbol (@found) {
    foreach my $label (@labels) {
      next if $label eq 'isodate';
        foreach my $key (@{$labels{$label}}) {
          $info{$symbol,$label} = $table{$symbol}->{$key} if exists $table{$symbol}->{$key};
        }
    }

    $quoter->store_date(\%info, $symbol, {eurodate => $info{$symbol,'date'}});
  }

  # Anything left in @symbols is a failure
  foreach my $symbol (@symbols) {
    $info{$symbol, 'success'}  = 0;
    $info{$symbol, 'errormsg'} = 'Not found'; 
  }

  return wantarray() ? %info : \%info;
}

1;

=head1 NAME

Finance::Quote::ASEGR - Obtain quotes from Athens Exchange Group

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("asegr","minoa");  # Only query ASEGR
    %info = Finance::Quote->fetch("greece","aaak");  # Failover to other sources OK.

=head1 DESCRIPTION

This module fetches information from https://www.athexgroup.gr.

This module is loaded by default on a Finance::Quote object. It's also possible
to load it explicitly by placing 'asegr' in the argument list to
Finance::Quote->new().

This module provides both the 'asegr' and 'greece' fetch methods.

=head1 LABELS RETURNED

The following labels may be returned: symbol date isodate close volume high low isin.

=head1 Terms & Conditions

Use of www.athexgroup.gr is governed by any terms & conditions of that site.

Finance::Quote is released under the GNU General Public License, version 2,
which explicitly carries a "No Warranty" clause.

=cut
