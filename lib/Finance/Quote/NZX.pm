#!/usr/bin/perl -w
# vi: set ts=4 sw=4 noai ic showmode showmatch:  

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

package Finance::Quote::NZX;

use strict;
use warnings;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use Encode;
use JSON qw( decode_json );
use LWP::UserAgent;
use Web::Scraper;
use String::Util qw(trim);

# VERSION

our $DISPLAY    = 'NZX - New Zealand Exchange';
our @LABELS     = qw/last isin name currency date isodate/;
our $METHODHASH = {subroutine => \&nzx, 
                   display => $DISPLAY, 
                   labels => \@LABELS};

sub methodinfo {
    return ( 
        nzx => $METHODHASH,
    );
}

sub labels { my %m = methodinfo(); return map {$_ => [@{$m{$_}{labels}}] } keys %m; }

sub methods {
  my %m = methodinfo(); return map {$_ => $m{$_}{subroutine} } keys %m;
}

sub nzx {
    my $quoter  = shift;
    my @symbols = @_;
    my $ua      = $quoter->user_agent();
    my %info;

    foreach my $symbol (@_) {
      eval {
        my $url   = "https://www.nzx.com/instruments/$symbol";
        my $reply = $ua->get($url);

        # JSON inside script id="__NEXT_DATA__" type="application/json" crossorigin="">
        my $widget = scraper {
            process '//script[contains(@id, "__NEXT_DATA__")]/text()', "script" => 'TEXT';
        };

        my $result = $widget->scrape($reply->decoded_content);
        #my $result = $widget->scrape($reply->content);
        ### RESULT : $result
        ### [<now>] Result->script: $result->{script}

        my $json = encode_utf8($result->{script});
        my $json_data;
        eval {$json_data = JSON::decode_json($json)};
        if ($@) {
            $info{ $symbol, 'success' } = 0;
            $info{ $symbol, 'errormsg' } = $@;
        }
        ### [<now>] JSON Data: $json_data

        unless ($json_data->{'props'}{'pageProps'}{'overview'}{'code'}
        eq $symbol) {
            $info{$symbol, 'success'} = 0;
            $info{$symbol, 'errormsg'} = 'Symbol not found';
            next;
        }
        
        $info{$symbol, 'success'}  = 1;
        $info{$symbol, 'currency'} = 'NZD';
        $info{$symbol, 'symbol'}  = $symbol;
        $info{$symbol, 'last'}    = $json_data->{'props'}{'pageProps'}{'overview'}{'priceAmount'};
        $info{$symbol, 'isin'}    = $json_data->{'props'}{'pageProps'}{'overview'}{'ISIN'};
        $info{$symbol, 'name'}    = $json_data->{'props'}{'pageProps'}{'overview'}{'name'};
      
        my $closePriceDate = $json_data->{'props'}{'pageProps'}{'overview'}{'closePriceDate'};
        $quoter->store_date(\%info, $symbol, {isodate => $closePriceDate});
      };
      
      if ($@) {
        my $error = "Search failed: $@";
        $info{$symbol, 'success'}  = 0;
        $info{$symbol, 'errormsg'} = trim($error);
      }
    }
    
    ### info : %info

    return wantarray() ? %info : \%info;
}

1;

=head1 NAME

Finance::Quote::NZX - Obtain quotes from New Zealand's
Exchange www.nzx.com

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %stockinfo = $q->fetch('nzx','TPW');

=head1 DESCRIPTION

This module obtains information fromwww.nzx.com.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::NZX:
last, isin, name, currency, date, isodate

=head1 Terms & Conditions

Use of nzx.com is governed by any terms & conditions of that site.

Finance::Quote is released under the GNU General Public License, version 2,
which explicitly carries a "No Warranty" clause.

=cut
