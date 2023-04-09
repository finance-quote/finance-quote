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

package Finance::Quote::Comdirect;

use strict;
use warnings;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use LWP::UserAgent;
use Web::Scraper;
use String::Util qw(trim);

# VERSION

our @labels = qw/last date isodate/;

sub labels {
  return ( comdirect => \@labels );
}

sub methods {
  return ( comdirect => \&comdirect );
}

sub comdirect {
  my $quoter  = shift;
  my @symbols = @_;
  my $ua      = $quoter->user_agent();
  my %info;

  foreach my $symbol (@_) {
    eval {
      my $url   = 'https://www.comdirect.de/inf/search/all.html?SEARCH_VALUE=' . $symbol;
      my $reply = $ua->get($url);

      ### [<now>] Fetched: $url
      my $data = scraper {
        process '/html/body/div[3]/div/div[2]/div[6]/div[1]/div/div/div[2]/div/div/table//td', 'table[]' => ['TEXT', sub{trim($_)}];
        process '/html/body/div[3]/div/div[2]/div[1]/div[1]/div/h1/text()', 'name' => ['TEXT', sub{trim($_)}];
        process '/html/body/div[3]/div/div[2]/div[1]/div[1]/div/div[2]/h2/text()[2]', 'isin' => ['TEXT', sub{trim($_)}];
      };

      my $result = $data->scrape($reply);
      
      ### Parsed: $result

      # Zeit appears twice as row label, so we need to differentiate them before converting to hash
      my $i      = 0;
      my @table  = map {$_ eq 'Zeit' ? $_ . $i++ : $_} @{$result->{table}};
      my %table  = @table;
      
      die "Missing expected fields" unless
        exists $table{Zeit0}   and
        exists $table{Aktuell} and
        exists $table{Hoch}    and
        exists $table{Tief}    and
        exists $table{"Er\x{f6}ffnung"};
      
      $table{Aktuell}          =~ s/,/./;
      $table{Hoch}             =~ s/,/./;
      $table{Tief}             =~ s/,/./;
      $table{"Er\x{f6}ffnung"} =~ s/,/./;

      $info{$symbol, 'last'}      = $1 if $table{Aktuell} =~ /^([0-9.]+)/;
      $info{$symbol, 'currency'}  = $1 if $table{Aktuell} =~ /([A-Z]+)$/;
      $info{$symbol, 'open'}      = $table{"Er\x{f6}ffnung"};
      $info{$symbol, 'high'}      = $table{Hoch};
      $info{$symbol, 'low'}       = $table{Tief};
      $info{$symbol, 'name'}      = $result->{name} if exists $result->{name};
      $info{$symbol, 'isin'}      = $result->{isin} if exists $result->{isin};

      $quoter->store_date(\%info, $symbol, {eurodate => $1}) if $table{Zeit0} =~ /([0-9]{2}[.][0-9]{2}[.][0-9]{2})/;
      
      $info{$symbol, 'method'}    = 'comdirect';
      $info{$symbol, 'success'}   = 1;
    };
    
    if ($@) {
      my $error = "Comdirect failed: $@";
      $info{$symbol, 'success'}  = 0;
      $info{$symbol, 'errormsg'} = trim($error);
    }
  }

  return wantarray() ? %info : \%info;
}

1;

=head1 NAME

Finance::Quote::Comdirect - Obtain quotes from https://www.comdirect.de

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch('comdirect', 'DE0007664039');
    %info = Finance::Quote->fetch('comdirect', 'Volkswagen');
    %info = Finance::Quote->fetch('comdirect', 'VWAGY');

=head1 DESCRIPTION

This module fetches information from https://www.comdirect.de.

This module is loaded by default on a Finance::Quote object. It's also possible
to load it explicitly by placing 'Comdirect' in the argument list to
Finance::Quote->new().

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::Comdirect:
isodate, last, currency, open, high, low, name, isin, method, success

=head1 TERMS & CONDITIONS

Use of www.comdirect.de is governed by any terms & conditions of that site.

Finance::Quote is released under the GNU General Public License, version 2,
which explicitly carries a "No Warranty" clause.

=cut

