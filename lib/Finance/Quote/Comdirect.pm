# vi: set ts=2 sw=2 noai ic showmode showmatch: 
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

use HTML::TableExtract;
use HTML::TreeBuilder;
use LWP::UserAgent;
use String::Util qw(trim);

# VERSION

our $DISPLAY    = 'Comdirect - Frankfurt and other exchanges';
our @LABELS     = qw/symbol name open high low last date currency isin method/;
our $METHODHASH = {subroutine => \&comdirect,
                   display => $DISPLAY, 
                   labels => \@LABELS};

sub methodinfo {
  return ( 
    comdirect => $METHODHASH,
  );
}

sub labels {
  my %m = methodinfo(); return map {$_ => [@{$m{$_}{labels}}] } keys %m;
}

sub methods {
  my %m = methodinfo(); return map {$_ => $m{$_}{subroutine} } keys %m;
}


sub comdirect {
  my $quoter  = shift;
  my @symbols = @_;
  my $ua      = $quoter->user_agent();
  my (%info, %pricetable, $metatag);

  foreach my $symbol (@_) {
      my $url   = 'https://www.comdirect.de/inf/search/all.html?SEARCH_VALUE=' . $symbol;
      my $reply = $ua->get($url);

      unless ($reply->is_success) {
        $info{ $symbol, "success" } = 0;
        $info{ $symbol, "errormsg" } = join ' ', $reply->code, $reply->message;
        next; 
      }
      my $body = $reply->decoded_content;

      ### [<now>] Body: $body

      my $te = HTML::TableExtract->new( count => 2, attribs => { class => 'simple-table' } );
      $te->parse($body);

      ### [<now>] TE: $te

      foreach my $row ($te->rows) {
        ### [<now>] Row: $row
        if ($row->[0] eq 'Zeit' && $pricetable{'Zeit'}) {next}
        $pricetable{$row->[0]} = $row->[1];
      }
      ### [<now>] Pricetable hash: %pricetable

      unless (exists $pricetable{Zeit} and exists $pricetable{Aktuell}
              and exists $pricetable{Hoch} and exists $pricetable{Tief}
              and exists $pricetable{"Er\x{f6}ffnung"}) {
        $info{ $symbol, "success" } = 0;
        $info{ $symbol, "errormsg" } = 'Parse failed.';
        next; 
      }
      
      $pricetable{Aktuell}          =~ s/,/./;
      $pricetable{Hoch}             =~ s/,/./;
      $pricetable{Tief}             =~ s/,/./;
      $pricetable{"Er\x{f6}ffnung"} =~ s/,/./;

      $info{$symbol, 'last'}      = $1 if $pricetable{Aktuell} =~ /^([0-9.]+)/;
      $info{$symbol, 'currency'}  = $1 if $pricetable{Aktuell} =~ /([A-Z]+)$/;
      $info{$symbol, 'open'}      = $pricetable{"Er\x{f6}ffnung"};
      $info{$symbol, 'high'}      = $pricetable{Hoch};
      $info{$symbol, 'low'}       = $pricetable{Tief};

      # Use HTML::TreeBuilder to get Name
      my $tree = HTML::TreeBuilder->new;
      if ($tree->parse($body)) {
        $tree->eof;
        if ($metatag = $tree->look_down(_tag => 'meta', name => 'description')) {
          my @list = split(',', $metatag->attr('content'));
          ### [<now>] List: @list
          $info{$symbol, 'name'} = $list[0];
          ($info{$symbol, 'isin'}) = $list[2] =~ /ISIN: ([A-Z0-9]{12}) /;
        }
      }

      $quoter->store_date(\%info, $symbol, {eurodate => $1}) if $pricetable{Zeit} =~ /([0-9]{2}[.][0-9]{2}[.][0-9]{2})/;

      $info{$symbol, 'method'}    = 'comdirect';
      $info{$symbol, 'success'}   = 1;
    
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

