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

package Finance::Quote::Sinvestor;

use strict;
use warnings;
use HTML::Entities;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use LWP::UserAgent;
use Web::Scraper;
use Encode qw(encode_utf8);

# VERSION

my $SINVESTOR_URL = 'https://web.s-investor.de/app/detail.htm?isin=';

our $DISPLAY    = 'Sinvestor';
# see https://web.s-investor.de/app/webauswahl.jsp for "Institutsliste"
our $FEATURES   = {'INST_ID' => 'Institut Id (default: 0000057 for "Sparkasse Krefeld")',
                   'EXCHANGE' => 'select market place (i.e. "gettex", "Xetra", "Tradegate")'};
our @LABELS     = qw/symbol isin last close exchange exchanges volume open price change p_change date time low high/;
our $METHODHASH = {subroutine => \&sinvestor,
                   display => $DISPLAY,
                   labels => \@LABELS,
                   features => $FEATURES};

sub labels {
  my %m = methodinfo(); return map {$_ => [@{$m{$_}{labels}}] } keys %m;
}

sub methodinfo {
    return (
        sinvestor => $METHODHASH,
        europe    => $METHODHASH,
    );
}

sub methods {
  my %m = methodinfo(); return map {$_ => $m{$_}{subroutine} } keys %m;
}

sub strip_exchange_name {
    my $exchange_name = shift;
    $exchange_name =~ s/^(Zürich) - SWX$/$1/g;
    return $exchange_name;
}

sub sinvestor {
  my $quoter  = shift;
  my $inst_id = exists $quoter->{module_specific_data}->{sinvestor}->{INST_ID} ?
                       $quoter->{module_specific_data}->{sinvestor}->{INST_ID} :
                       '0000057';

  my $exchange_code = exists $quoter->{module_specific_data}->{sinvestor}->{EXCHANGE} ?
                             $quoter->{module_specific_data}->{sinvestor}->{EXCHANGE} :
                             undef;

  my %exchange2code = ( 'Gettex'            => 'GTX',
                        'Tradegate'         => 'TDG',
                        'Stuttgart'         => 'STU',
                        'Frankfurt'         => 'FRA',
                        'Xetra'             => 'GER',
                        'Paris'             => 'PAR',
                        "Düsseldorf"        => 'DUS',
                        'Berlin'            => 'BER',
                        'Hamburg'           => 'HAM',
                        'Hannover'          => 'HAN',
                        "München"           => 'MUN',
                        'Refinitiv CT'      => 'RCT',
                        'Zürich'            => 'SWX',
                        'Zürich - SWX'      => 'SWX',
                        'NASDAQ - Pink Sheets' => 'PNK',
                        # undef means: this exchange is not selectable by name
                        'Quotrix'           => undef, # '0QT', 'QTX',
                        'KVG Fondskurse'    => undef, # 'LIP',
                        'Lipper Fondsdaten' => undef, # 'LIP'
                        );

  my %exchange2code_uc = ( map { uc($_) => $exchange2code{$_} } keys %exchange2code );

  if (defined($exchange_code) and $exchange_code !~ /^[A-Z0-9]{3}$/) {
    # we need the exchange_code for the querry
    if (exists $exchange2code_uc{uc($exchange_code)}
       and defined $exchange2code_uc{uc($exchange_code)}) {
        $exchange_code = $exchange2code_uc{uc($exchange_code)};
    } else {
        die("unsupported exchange(-code): $exchange_code");
    }
  }

  my $ua      = $quoter->user_agent();
  my $agent   = $ua->agent;
  $ua->agent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36');

  my %info;

  foreach my $symbol (@_) {
    my $url = $SINVESTOR_URL
                . $symbol
                . '&INST_ID='
                . $inst_id;

    $url .= '&boerse=' . $exchange_code if defined($exchange_code);

    eval {
      my $tree = HTML::TreeBuilder->new_from_url($url);

      my $lastvalue = $tree->look_down('class'=>'si_seitenbezeichnung');

      if (defined($lastvalue)) {
        $info{ $symbol, 'success' } = 0;
        $info{ $symbol, 'errormsg' } = 'Invalid institute id. Get a valid institute id from https://web.s-investor.de/app/webauswahl.jsp';
      } else {
        $lastvalue = $tree->look_down('id'=>'kursdaten') or die("Not found");

        my $td1 = ($lastvalue->look_down('_tag'=>'td'))[1];
        my @child = $td1->content_list;
        my $isin = $child[0];

        $td1 = ($lastvalue->look_down('_tag'=>'td'))[3];
        @child = $td1->content_list;
        my $sharename = encode_utf8($child[0]);

        $td1 = ($lastvalue->look_down('_tag'=>'td'))[5];
        @child = $td1->content_list;
        my $exchange = encode_utf8($child[0]);

        $td1 = ($lastvalue->look_down('_tag'=>'td'))[7];
        @child = $td1->content_list;
        my $date = substr($child[0], 0, 8);
        my $time = substr($child[0], 9, 5); # CE(S)T

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

        my $table = ($lastvalue->look_down('_tag'=>'table'))[1];

        $td1 = ($table->look_down('_tag'=>'td'))[1];
        @child = $td1->content_list;
        my $low = $child[0];
        $low =~ s/\.//g;
        $low =~ s/,/\./;

        $td1 = ($table->look_down('_tag'=>'td'))[2];
        @child = $td1->content_list;
        my $high = $child[0];
        $high =~ s/\.//g;
        $high =~ s/,/\./;

        my $t = $tree->look_down('_tag'=>'table', 'id'=>'detailHandelsplatz');
        my %exchanges = ();
        foreach ($t->look_down('_tag'=>'tr', 'class'=>'si_click_nav rowLink')) {
            my $a = $_->attr('data-dest');
            if ($a and $a =~ /boerse=([^&"]+)/) {
                my $code = $1;
                my $name = encode_utf8(($_->look_down('_tag'=>'td'))[0]->as_text);
                $exchanges{ $name } = $code;
                $name = strip_exchange_name($name);
                $exchanges{ $name } = $code if not exists $exchanges{ $name };
            }
        }
        if (defined($exchange_code)) {
            my $key = strip_exchange_name($exchange);
            unless(exists($exchanges{ $key }) and $exchanges{ $key } eq $exchange_code) {
                die("$symbol not found on marketplace: $exchange_code");
            }
        }

        my @searchvalue = $tree->look_down('class'=>'contentBox oneColum');
        my $isFound = 0;
        foreach (@searchvalue)
        {
          if (ref(($_->content_list)[0]) eq "HTML::Element" and ($_->content_list)[0]{'_content'}[0]{'_content'}[0] eq 'Aktuelle Vergleichszahlen')
          {
            $isFound = 1;

            #-- open
            $td1 = ($_->look_down('_tag'=>'td'))[4];
            @child = $td1->content_list;
            my $open = $child[0];
            $open =~ s/\.//g;
            $open =~ s/,/\./;

            #-- change (absolute change)
            $td1 = ($_->look_down('_tag'=>'td'))[13];
            @child = $td1->content_list;
            my $change = $child[0];
            $change =~ s/\.//g;
            $change =~ s/,/\./;
            my $encchange = encode_entities($change);
            my @splitcchange= split ('&',$encchange);
            $change = $splitcchange[0];

            #-- p_change (relative change)
            $td1 = ($_->look_down('_tag'=>'td'))[16];
            @child = $td1->content_list;
            my $p_change =$child[0];
            $p_change =~ s/[\.|%]//g;
            $p_change =~ s/,/\./;

            #-- close
            $td1 = ($_->look_down('_tag'=>'td'))[34];
            @child = $td1->content_list;
            my $close = $child[0];
            $close =~ s/\.//g;
            $close =~ s/,/\./;
            my $encclose = encode_entities($close);
            my @splitclose= split ('&',$encclose);
            $close = $splitclose[0];

            $info{$symbol, 'success'}   = 1;
            $info{$symbol, 'method'}    = 'Sinvestor';
            $info{$symbol, 'symbol'}    = $isin;
            $info{$symbol, 'isin'}      = $isin;
            $info{$symbol, 'name'}      = $sharename;
            $info{$symbol, 'exchange'}  = $exchange;
            $info{$symbol, 'exchanges'} = [ grep { exists $exchange2code_uc{uc($_)}
                                              and defined $exchange2code_uc{uc($_)}
                                                 } sort keys %exchanges ];
            $info{$symbol, 'last'}      = $price;
            $info{$symbol, 'price'}     = $price;
            $info{$symbol, 'close'}     = $close;
            $info{$symbol, 'change'}    = $change;
            $info{$symbol, 'p_change'}  = $p_change;
            $info{$symbol, 'volume'}    = $volume;
            $info{$symbol, 'currency'}  = $currency;
            $quoter->store_date(\%info, $symbol, {eurodate => $date});
            $info{$symbol, 'time'}     = $time;
            $info{$symbol, 'open'}     = $open;
            $info{$symbol, 'low'}      = $low;
            $info{$symbol, 'high'}     = $high;

            if (DEBUG) {
                my %unknown_exchanges = map { $_ => $exchanges{$_} }
                                        grep { not exists $exchange2code_uc{uc($_)} }
                                        sort keys %exchanges;
                ### unknown_exchanges: %unknown_exchanges
                $info{$symbol, '_unknown_exchanges'} = { %unknown_exchanges };
            }
          }
        }

        if (!$isFound)
        {
           $info{$symbol, 'success'}  = 0;
           $info{$symbol, 'errormsg'} = "Error retreiving $symbol: $@";
        }
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

Finance::Quote::Sinvestor - Obtain quotes from S-Investor platform.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;
    or
    $q = Finance::Quote->new('Sinvestor', 'sinvestor' => {INST_ID => 'your institute id'});
    or
    $q = Finance::Quote->new('Sinvestor', 'sinvestor' => {EXCHANGE => 'Xetra'});

    %info = Finance::Quote->fetch("Sinvestor", "DE000ENAG999");  # Only query Sinvestor
    %info = Finance::Quote->fetch("europe", "brd");     # Failover to other sources OK.

=head1 DESCRIPTION

This module fetches information from https://s-investor.de/, the investment platform
of the German Sparkasse banking group. It fetches share prices from various
marketplaces. The marketplace is returned in the "exchange" field.

Suitable for shares, ETFs and funds that are traded in Germany.

This module is loaded by default on a Finance::Quote object. It's also possible
to load it explicitly by placing "Sinvestor" in the argument list to
Finance::Quote->new().

This module provides "Sinvestor" and "europe" fetch methods.

Information obtained by this module may be covered by s-investor.de terms and
conditions.

=head1 EXCHANGE

https://www.s-investor.de/ supports different market places. A default is not specified.

  "Xetra" alias "GER"
  "Tradegate" alias "TDG"
  "gettex" alias "GTX"
  "Berlin" alias "BER"
  ... any many more ...

The EXCHANGE may be set by providing a module specific hash to
Finance::Quote->new as in the above example (optional).

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
exchanges
last
method
success
symbol
isin
date
time
volume
price
close
open
low
high
change
p_change
