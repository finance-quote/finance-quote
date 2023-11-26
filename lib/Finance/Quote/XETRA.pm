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

package Finance::Quote::XETRA;

use strict;
use warnings;
use HTML::Entities;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use LWP::UserAgent;
use Web::Scraper;

# VERSION

my $xetra_URL = 'https://web.s-investor.de/app/detail.htm?boerse=GER&isin=';

sub methods {
  return (xetra   => \&xetra,
          europe  => \&xetra);
}

sub parameters {
  return ('INST_ID');
}

our @labels = qw/symbol last close exchange volume open price change p_change/;

sub labels {
  return (xetra   => \@labels,
          europe  => \@labels);
}

sub xetra {
  my $quoter  = shift;
  my $inst_id = exists $quoter->{module_specific_data}->{xetra}->{INST_ID} ?
                       $quoter->{module_specific_data}->{xetra}->{INST_ID} :
                       '0000057';
  my $ua      = $quoter->user_agent();
  my $agent   = $ua->agent;
  $ua->agent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36');

  my %info;
  my $url;
  my $reply;

  foreach my $symbol (@_) {
    eval {
      my $url = $xetra_URL
                . $symbol
                . '&INST_ID='
                . $inst_id;

      my $symlen = length($symbol);

      my $tree = HTML::TreeBuilder->new_from_url($url);

      my $lastvalue = $tree->look_down('class'=>'si_seitenbezeichnung');

      if (defined($lastvalue)) {
        $info{ $symbol, 'success' } = 0;
        $info{ $symbol, 'errormsg' } = 'Invalid institute id. Get a valid institute id from https://web.s-investor.de/app/webauswahl.jsp';
      } else {
        $lastvalue = $tree->look_down('id'=>'kursdaten');

        my $td1 = ($lastvalue->look_down('_tag'=>'td'))[1];
        my @child = $td1->content_list;
        my $isin = $child[0];

        $td1 = ($lastvalue->look_down('_tag'=>'td'))[3];
        @child = $td1->content_list;
        my $sharename = $child[0];

        $td1 = ($lastvalue->look_down('_tag'=>'td'))[5];
        @child = $td1->content_list;
        my $exchange = $child[0];

        $td1 = ($lastvalue->look_down('_tag'=>'td'))[7];
        @child = $td1->content_list;
        my $date = substr($child[0], 0, 8);

        $td1 = ($lastvalue->look_down('_tag'=>'td'))[9];
        @child = $td1->content_list;
        my $price = $child[0];
        $price =~ s/\.//g;
        $price =~ s/,/\./;
        my $encprice = encode_entities($price);
        my @splitprice= split ('&',$encprice);
        $price = $splitprice[0];

        $td1 = ($lastvalue->look_down('_tag'=>'td'))[11];
        @child = $td1->content_list;
        my $currency = $child[0];
        $currency =~ s/Euro/EUR/;

        $td1 = ($lastvalue->look_down('_tag'=>'td'))[13];
        @child = $td1->content_list;
        my $volume = $child[0];

        $lastvalue = ($tree->look_down('class'=>'contentBox oneColum'))[1];

        #-- change (absolute change)
        $td1 = ($lastvalue->look_down('_tag'=>'td'))[13];
        @child = $td1->content_list;
        my $change = $child[0];
        $change =~ s/\.//g;
        $change =~ s/,/\./;
        my $encchange = encode_entities($change);
        my @splitcchange= split ('&',$encchange);
        $change = $splitcchange[0];

        #-- p_change (relative change)
        $td1 = ($lastvalue->look_down('_tag'=>'td'))[16];
        @child = $td1->content_list;
        my $p_change =$child[0];
        $p_change =~ s/[\.|%]//g;
        $p_change =~ s/,/\./;

        #-- close
        $td1 = ($lastvalue->look_down('_tag'=>'td'))[34];
        @child = $td1->content_list;
        my $close = $child[0];
        $close =~ s/\.//g;
        $close =~ s/,/\./;
        my $encclose = encode_entities($close);
        my @splitclose= split ('&',$encclose);
        $close = $splitclose[0];

        $info{$symbol, 'success'}   = 1;
        $info{$symbol, 'method'}    = 'xetra';
        $info{$symbol, 'symbol'}    = $isin;
        $info{$symbol, 'name'}      = $sharename;
        $info{$symbol, 'exchange'}  = $exchange;
        $info{$symbol, 'last'}      = $price;
        $info{$symbol, 'price'}     = $price;
        $info{$symbol, 'close'}     = $close;
        $info{$symbol, 'change'}    = $change;
        $info{$symbol, 'p_change'}  = $p_change;
        $info{$symbol, 'volume'}    = $volume;
        $info{$symbol, 'currency'}  = $currency;
  #      $info{$symbol, 'date'}     = $date;
        $quoter->store_date(\%info, $symbol, {eurodate => $date});
      }
    };
    if ($@) {
      $info{$symbol, 'success'}  = 0;
      $info{$symbol, 'errormsg'} = "Error retreiving $symbol: $@";
    }


}
  $ua->agent($agent);

  return wantarray() ? %info : \%info;
}

1;

=head1 NAME

Finance::Quote::xetra - Obtain quotes from S-Investor platform.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;
    or
    $q = Finance::Quote->new('XETRA', 'xetra' => {INST_ID => 'your institute id'});

    %info = Finance::Quote->fetch("xetra", "DE000ENAG999");  # Only query xetra
    %info = Finance::Quote->fetch("europe", "brd");     # Failover to other sources OK.

=head1 DESCRIPTION

This module fetches information from https://s-investor.de/, the investment platform
of the German Sparkasse banking group. It fetches share prices from XETRA,
a major German trading platform. The prices on XETRA serve as the basis for calculating
the DAX and other stock market indices.

Suitable for shares and ETFs that are traded in Germany.

This module is loaded by default on a Finance::Quote object. It's also possible
to load it explicitly by placing "XETRA" in the argument list to
Finance::Quote->new().

This module provides "xetra" and "europe" fetch methods.

Information obtained by this module may be covered by s-investor.de terms and
conditions.

=head1 INST_ID

https://s-investor.de/ supports different institute IDs. The default value "0000057" is
used (Krefeld) if no institute ID is provided. A list of institute IDs is provided here:
https://web.s-investor.de/app/webauswahl.jsp

The INST_ID may be set by providing a module specific hash to
Finance::Quote->new as in the above example (optional).

=head1 LABELS RETURNED

The following labels are returned:
currency
exchange
last
method
success
symbol
volume
price
close
change
p_change
