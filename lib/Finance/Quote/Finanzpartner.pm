# Finance::Quote Perl module to retrieve quotes from Finanzpartner.de
#    Copyright (C) 2007  Jan Willamowius <jan@willamowius.de>
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
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

package Finance::Quote::Finanzpartner;

use strict;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use Web::Scraper;
use Encode;

# VERSION

my $FINANZPARTNER_URL = "https://www.finanzpartner.de/fi/";

sub methods {return (finanzpartner        => \&finanzpartner);}
sub labels { return (finanzpartner=>[qw/name date price last method/]); } # TODO

sub finanzpartner
{
  my $quoter = shift;     # The Finance::Quote object.
  my @stocks = @_;
  my $ua = $quoter->user_agent();
  my %info;

  foreach my $stock (@stocks) {
    eval {
      my @headers = (
          "authority"                 => "www.finanzpartner.de",
          "sec-ch-ua"                 => '"Google Chrome";v="87", " Not;A Brand";v="99", "Chromium";v="87"',
          "sec-ch-ua-mobile"          => "?0",
          "upgrade-insecure-requests" => "1",
          "user-agent"                => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 11_1_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.88 Safari/537.36',
          "accept"                    => "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9",
          "accept-language"           => "en-US,en;q=0.9",
          "sec-ch-ua"                 => "\"Google Chrome\";v=\"87\", \" Not;A Brand\";v=\"99\", \"Chromium\";v=\"87\"",
          "sec-fetch-dest"            => "document",
          "sec-fetch-mode"            => "navigate",
          "sec-fetch-site"            => "none",
          );

      my $url = $FINANZPARTNER_URL . $stock . '/';

      ### url : $url

      my $reply = $ua->get($url, @headers);

      my $processor = scraper {
        process 'span.kurs-m.pull-left', 'price[]' => 'TEXT';
        process 'h1 > small', 'isin[]'             => 'TEXT';
        process 'div.col-md-2', 'date[]'           => 'TEXT';
        process 'h1 > span', 'name[]'              => 'TEXT';
      };
 
      my $data = $processor->scrape(decode_utf8 $reply->content);

      ### data: $data
      
      die "Unexpected price format" unless exists $data->{price} and $data->{price}->[0] =~ /^([0-9.]+) ([A-Z]+)$/;
      $info{$stock, "last"}     = $1;
      $info{$stock, "currency"} = $2;
      
      die "Unexpected date format" unless exists $data->{date} and $data->{date}->[0] =~ /([0-9]{2}[.][0-9]{2}[.][0-9]{4})$/;
      $quoter->store_date(\%info, $stock, {eurodate => $1});
        
      $info{$stock,"method"}  = "finanzpartner";
      $info{$stock,"symbol"}  = $stock;
      $info{$stock,"success"} = 1;
    };

    if ($@) {
      $info{$stock,"errormsg"} = $@;
      $info{$stock,"success"}  = 0;
    }
  }
  
  return wantarray ? %info : \%info;
}

1;

=head1 NAME

Finance::Quote::Finanzpartner - Obtain quotes from Finanzpartner.de.

=head1 SYNOPSIS

use Finance::Quote;

$q = Finance::Quote->new("Finanzpartner");

%info = $q->fetch("finanzpartner","LU0055732977");

=head1 DESCRIPTION

This module obtains quotes from Finanzpartner.de (http://www.finanzpartner.de) by WKN or ISIN.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::Finanzpartner:
name, date, price, last, method.

=head1 SEE ALSO

Finanzpartner, http://www.finanzpartner.de/

Finance::Quote;

=cut
