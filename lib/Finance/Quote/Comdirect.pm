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
use Encode qw(encode_utf8);

# VERSION

our $DISPLAY    = 'Comdirect - Frankfurt and other exchanges';
our $FEATURES   = { 'EXCHANGE' => 'select market place (i.e. "gettex", "Xetra", "Tradegate")' };
our @LABELS     = qw/symbol name open high low last date time p_change ask bid currency isin wkn method exchange exchanges/;
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
  my (%info, %pricetable, %infotable);

  foreach my $symbol (@_) {
      my $try = 0;
      my $url = 'https://www.comdirect.de/inf/search/all.html?SEARCH_VALUE=' . $symbol;

RETRY:
      ++$try;
      my $reply = $ua->get($url);

      unless ($reply->is_success) {
        $info{ $symbol, "success" } = 0;
        $info{ $symbol, "errormsg" } = join ' ', $reply->code, $reply->message;
        next; 
      }
      my $body = $reply->decoded_content;

      ### [<now>] Body: $body

      my $tree = HTML::TreeBuilder->new;
      unless ($tree->parse(encode_utf8($body))) {
        $info{ $symbol, "success" } = 0;
        $info{ $symbol, "errormsg" } = 'Parse body failed';
        next;
      }

      my $exchange = exists $quoter->{module_specific_data}->{comdirect}->{EXCHANGE} ?
                            $quoter->{module_specific_data}->{comdirect}->{EXCHANGE} : undef;

      my $select = $tree->look_down(_tag => 'select', name=> 'ID_NOTATION', id=> "marketSelect");
      unless($select) {
        $info{ $symbol, "success" } = 0;
        $info{ $symbol, "errormsg" } = 'Parse marketplaces failed.';
        next;
      }

      my %exchange2nid = map { $_->as_text => $_->attr('value') }
        grep { ref eq 'HTML::Element' and $_->tag eq 'option' } $select->content_list;

      my $option = $select->look_down(_tag => 'option', selected => 'selected');
      unless($option) {
        $info{ $symbol, "success" } = 0;
        $info{ $symbol, "errormsg" } = 'Parse selected marketplace failed.';
        next;
      }

      if ($exchange and $exchange ne $option->as_text) {
        unless (exists($exchange2nid{$exchange}) and $try < 2) {
            $info{ $symbol, "success" } = 0;
            $info{ $symbol, "errormsg" } = 'Marketplace not found: ' . "'".$exchange."'";
            next;
        }

        my $u = $reply->request->url;
        $u->query_param("ID_NOTATION" => $exchange2nid{$exchange});
        $url = $u->as_string;

        goto RETRY;
      }

      $info{$symbol, 'exchanges'} = [ sort keys %exchange2nid ];
      $info{$symbol, 'exchange'} = $option->as_text;
      $info{$symbol, 'notation_id'} = $option->attr('value');

      my $h1 = $tree->look_down(_tag => 'h1');
      if ($h1) {
        $info{$symbol, 'name'} = trim($h1->as_text);
      }

      my $div = $tree->look_down(_tag => 'div', class => "realtime-indicator");
      if ($div) {
        my @span = $div->look_down(_tag => 'span');
        if (scalar(@span) >= 2) {
          $info{$symbol, 'last'}     = $1 if trim($span[-2]->as_text) =~ /^([0-9.]+)/;
          $info{$symbol, 'currency'} = $1 if trim($span[-1]->as_text) =~ /^([A-Z]+)/;
        }
      }

      my $te = HTML::TableExtract->new( count => 4, attribs => { class => 'simple-table' } );
      ### [<now>] TE: $te
      unless ( $te->parse($body) and $te->first_table_found) {
        $info{ $symbol, "success" } = 0;
        $info{ $symbol, "errormsg" } = 'No price data found';
        next; 
      }

      foreach my $row ($te->rows) {
        ### [<now>] Row: $row
        if (defined($row->[0])) {
          $infotable{$row->[0]} = $row->[1];
        }
      }

      $te = HTML::TableExtract->new( count => 2, attribs => { class => 'simple-table' } );
      ### [<now>] TE: $te
      unless ( $te->parse($body) and $te->first_table_found) {
        $info{ $symbol, "success" } = 0;
        $info{ $symbol, "errormsg" } = 'No price data found';
        next; 
      }

      foreach my $row ($te->rows) {
        ### [<now>] Row: $row
        if ($row->[0] eq 'Zeit' && $pricetable{'Zeit'}) {next}
        $pricetable{$row->[0]} = trim($row->[1]);
      }
      ### [<now>] Pricetable hash: %pricetable

      unless (exists $pricetable{Zeit}) {
        $info{ $symbol, "success" } = 0;
        $info{ $symbol, "errormsg" } = 'Parse failed.';
        next; 
      }

      my %mapping = ( 'high' => 'Hoch',
                      'low' => 'Tief',
                      'bid' => 'Geld',
                      'ask' => 'Brief',
                      'open' => "Er\x{f6}ffnung",
                      'close' => "Schluss Vortag" );

      while ((my $fqkey, my $cbkey) = each (%mapping)) {
        $info{$symbol, $fqkey} = $1.'.'.$2
          if (exists($pricetable{$cbkey})
            and defined($pricetable{$cbkey})
            and $pricetable{$cbkey} =~ /^(\d+),(\d+)/);
      }

      $info{$symbol, 'p_change'}  = $1 if $pricetable{"Diff. Vortag"} =~ /([+-][0-9]+\.[0-9]+)\x{a0}%/;

      $info{$symbol, 'isin'}      = $infotable{ISIN};
      $info{$symbol, 'wkn'}       = $infotable{WKN};
      $info{$symbol, 'symbol'}    = $infotable{Symbol};

      if ($pricetable{Zeit} =~ /([0-9]{2}[.][0-9]{2}[.][0-9]{2}) ([ 0-9][0-9]:[0-9][0-9])/) {
        $quoter->store_date(\%info, $symbol, {eurodate => $1});
        $info{$symbol, 'time'} = $2;
      }

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
    or
    $q = Finance::Quote->new("Comdirect", "comdirect" => { "EXCHANGE" => "Xetra" });

    %info = Finance::Quote->fetch('comdirect', 'DE0007664039');
    %info = Finance::Quote->fetch('comdirect', 'Volkswagen');
    %info = Finance::Quote->fetch('comdirect', 'VWAGY');

    @exchanges = @{ $info{ "VWAGY", "exchanges" } }; # List of available marketplaces

=head1 DESCRIPTION

This module fetches information from https://www.comdirect.de.

This module is loaded by default on a Finance::Quote object. It's also possible
to load it explicitly by placing 'Comdirect' in the argument list to
Finance::Quote->new().

=head1 EXCHANGE

https://www.comdirect.de/ supports different marketplaces:

  "gettex"
  "Xetra"
  "Frankfurt"
  "Tradegate"
  ... any many more ...

The EXCHANGE may be set by providing a module specific hash to
Finance::Quote->new as in the above example (optional).

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::Comdirect:
isodate, time, last, currency, open, high, low, name, isin, wkn,
p_change, ask, bid, method, exchange, success, exchanges

=head1 TERMS & CONDITIONS

Use of www.comdirect.de is governed by any terms & conditions of that site.

Finance::Quote is released under the GNU General Public License, version 2,
which explicitly carries a "No Warranty" clause.

=cut

