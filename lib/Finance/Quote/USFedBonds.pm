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

package Finance::Quote::USFedBonds;

use strict;
use warnings;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use LWP::UserAgent;
use Web::Scraper;
use String::Util qw(trim);
use DateTime;

# VERSION
my $TREASURY_MAINURL = ("http://www.treasurydirect.gov/");
my $TREASURY_URL = ($TREASURY_MAINURL."indiv/tools/");

sub methods {
    return (usfedbonds => \&treasury);
}

sub labels {
    my @labels = qw/method source name symbol currency last date isodate nav price/;
    return (usfedbonds => \@labels);
}

sub treasury {
  my $quoter  = shift;
  my @symbols = @_;
  my $ua      = $quoter->user_agent();
  my %info;

  my %month; 
  @month{qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/} = (1 .. 12);
  @month{qw/January February March April May June July August September October November December/} = (1 .. 12);

  my $root  = 'https://www.treasurydirect.gov/indiv/tools/';
  my $url   = $root . 'tools_savingsbondvalues_historical.htm';
  my $reply = $ua->get($url);

  ### [<now>] Fetched: $url
  my $data = scraper {
    process '//*[@id="content"]/p[2]/a', 'links[]' => {'name' => 'TEXT', 'href' => '@href'};
  };

  my $result = $data->scrape($reply);

  # Build a map from "YYYYMM" of redemption to URL
  my %map;
  foreach my $link (@{$result->{links}}) {
    if ($link->{name} =~ /^(?<startmonth>[A-Za-z]+)\s+(?<startyear>[0-9]{4}).*?(?<endmonth>[A-Za-z]+)\s+(?<endyear>[0-9]{4})$/) {
      my $start = DateTime->new(year => $+{startyear}, month => $month{$+{startmonth}});
      my $end   = DateTime->new(year => $+{endyear}, month => $month{$+{endmonth}});
      
      while ($start <= $end) {
        my $key    = $start->strftime('%Y%m');
        $map{$key} = $link->{href};

        $start->add(months => 1); 
      }
    }
  }

  my %cache;

  foreach my $symbol (@_) {
    eval {
      die "$symbol does not match expected format" unless $symbol =~ /^(?<series>[IENS])(?<issueyear>[0-9]{4})(?<issuemonth>[0-9]{2})[.](?<redemptionyear>[0-9]{4})(?<redemptionmonth>[0-9]{2})$/;
     
      my $issuemonth      = $+{issuemonth};
      my $redemptionmonth = $+{redemptionmonth};
      my $redemptionyear  = $+{redemptionyear};

      my $redemption = $+{redemptionyear} . $+{redemptionmonth};
      my $url        = $map{$redemption};
      my $row_index  = $+{series} . $+{redemptionyear} . $+{redemptionmonth} . $+{issueyear};

      # row index is [series(1) + redemption year(4) + redemption month(2)](7) + issue year(4) 
      unless (exists $cache{$url}) {
        my %table = map {$_->[0] . $_->[1] => $_}
          map {[unpack("A7A4A6A6A6A6A6A6A6A6A6A6A6A6", $_)]}
            split /\n/, $ua->get($url)->content();
        $cache{$url} = \%table;
      }
      
      my $row       = $cache{$url}->{$row_index};

      ### Looking for : $symbol, $redemption
      ### url         : $url
      ### row         : $row_index

      die "value not found for $symbol" unless $row->[1 + $issuemonth] =~ /[0-9]{6}/;
      
      $info{$symbol, "price"} = sprintf('%.2f', $row->[1 + $issuemonth]/100);
      $info{$symbol, "currency"} = "USD";

      $quoter->store_date(\%info, $symbol, {usdate => "$redemptionmonth/01/$redemptionyear"});

      $info{$symbol, "success"} = 1;
    };

    if ($@) {
      my $error = "USFedBonds failed: $@";
      $info{$symbol, 'success'}  = 0;
      $info{$symbol, 'errormsg'} = trim($error);
    }
  }
 
  return wantarray() ? %info : \%info;
}

1;

__END__

=head1 NAME

Finance::Quote::USFedBonds - Get US Federal Bond redemption values from http://www.treasurydirect.gov

=head1 SYNOPSIS

    use Finance::Quote;

    $q    = Finance::Quote->new();
    %info = $q->fetch('usfedbonds', 'E197001.200606');

=head1 DESCRIPTION

Access redemption values for US Federal Bonds from the treasury.

Bonds should be identified in the following manner:

SERIES(1)         : I/E/N/S

ISSUEDATE(6)      : YYYYMM

SEPERATOR(1)      : "."

REDEMPTIONDATE(6) : YYYYMM

e.g. E200101.200501


=head1 LABELS RETURNED

price, date, isodate

=head1 TERMS & CONDITIONS

Use of www.treasurydirect.gov is governed by any terms & conditions of that site.

Finance::Quote is released under the GNU General Public License, version 2,
which explicitly carries a "No Warranty" clause.


=cut
