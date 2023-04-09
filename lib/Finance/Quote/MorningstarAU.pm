#!/usr/bin/perl -w
#
#    Copyright (C) 2019, Jalon Avens
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

package Finance::Quote::MorningstarAU;

use strict;
use warnings;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use JSON;
use Web::Scraper;

# VERSION

sub methods {
  return (aufunds => \&morningstarau, morningstarau => \&morningstarau,);
}

sub labels {
  my @labels = qw/currency date isodate method name price symbol/;
  return (aufund => \@labels, morningstarau => \@labels);
}

sub morningstarau {
  my $quoter  = shift;
  my @symbols = @_;
  my $ua      = $quoter->user_agent();

  return unless @symbols;

  my %info;

  foreach my $symbol (@symbols) {
    eval {
      my $lookup = "https://www.morningstar.com.au/Ausearch/SecurityCodeAutoLookup?q=$symbol";
      my $reply  = $ua->get($lookup);

      die "Failed to find APIR $symbol" unless $reply->code == 200;

      my $json_data = JSON::decode_json $reply->content;

      ### MorningstarAU lookup: $json_data 

      die "Failed to find unique APIR $symbol" unless $json_data and $json_data->{hits}->{total} == 1;

      my $id = $json_data->{hits}->{hits}[0]->{_source}->{Symbol};
    
      ### MorningstarAU input: $symbol
      ### MorningstarAU id   : $id

      my $url = "https://www.morningstar.com.au/Funds/FundReport/$id";
      $reply  = $ua->get($url);

      die "Failed to fetch quote for $symbol using id $id" unless $reply->code == 200;

      my $processor = scraper {
        process 'div#maincontent h1.RecentHeading', 'name' => ['TEXT',  sub {s/^\s*|\s*$//g}];
        process 'h3 + p.fundreportsubheading', 'date[]' => ['TEXT', qr/^as at ([0-9]{1,2} [A-Za-z]{3} [0-9]{4})/];
        process 'table.tablefundreport td', 'table[]' => ['TEXT', sub {s/\s//g}];
      };

      my $data = $processor->scrape($reply);

      ### data: $data

      my %table = @{$data->{table}};

      die "Mismatch symbol $symbol to APIR Code $table{APIRCode}" unless $symbol eq $table{APIRCode};

      $info{$symbol, 'success'}  = 1;
      $info{$symbol, 'currency'} = $table{BaseCurrency} eq '$A' ? 'AUD' : $table{BaseCurrency};

      my @dates = grep defined, @{$data->{date}};
      $quoter->store_date(\%info, $symbol, {'eurodate' => $dates[-1]});

      $info{$symbol, 'method'}   = 'morningstarau';
      $info{$symbol, 'name'}     = $data->{name};
      $info{$symbol, 'price'}    = $table{'ExitPrice$'};
      $info{$symbol, 'symbol'}   = $table{APIRCode};
    };

    if ($@) {
      chomp($@);
      ### error: $@

      $info{$symbol, 'success'}  = 0;
      $info{$symbol, 'errormsg'} = $@;
    }
  }

  return wantarray() ? %info : \%info;
}

1;

=head1 NAME

Finance::Quote::MorningstarAU - Obtain Australian managed fund quotes from morningstar.com.au

=head1 SYNOPSIS

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("morningstarau","<APIR> ...");  # Only query morningstar.com.au using APIRs
    %info = Finance::Quote->fetch("aufunds","<APIR> ...");  # Failover to other sources

=head1 DESCRIPTION

This module fetches information from the MorningStar Funds service
https://morningstar.com.au to provide quotes on Australian managed funds in
AUD.

Funds are identified by their APIR code.

This module is loaded by default on a Finance::Quote object. It's also possible
to load it explicitly by placing "morningstarau" in the argument list to
Finance::Quote->new().

=head2 Managed Funds

This module provides both the "morningstarau" and "aufunds" fetch methods for
fetching Australian funds prices from morningstar.com.au. Please use the
"aufunds" fetch method if you wish to have failover with future sources for of
Ausralian fund quotations which might be provided by other Finance::Quote
modules. Using the "morningstarau" method will guarantee that your information
only comes from the morningstar.com.au website.

=head1 LABELS RETURNED

The following labels may be returned by
Finance::Quote::MorningstarAU::morningstarau:

    currency, date, isodate, method, name, price, symbol

=head1 SEE ALSO

Morningstart Australia website https://morningstar.com.au

=head1 AUTHOR

Jalon Avens & others

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2019 by Jalon Avens

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or (at
your option) any later version.

=cut
