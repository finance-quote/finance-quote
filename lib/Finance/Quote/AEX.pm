#!/usr/bin/perl -w
# vi: set ts=4 sw=4 noai ic showmode showmatch:  

#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
#    02110-1301, USA

package Finance::Quote::AEX;

use strict;
use warnings;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use vars qw($AEX_URL);

use LWP::UserAgent;
use Web::Scraper;
use String::Util qw(trim);

# VERSION

our $DISPLAY = 'Euronext Amsterdam';
our @labels  = qw/name symbol price last date time p_change bid ask offer open high low close volume currency method exchange/;

sub methods { 
  return (
      dutch => {subroutine => \&aex, display => $DISPLAY, labels => \@labels},
      aex   => {subroutine => \&aex, display => $DISPLAY, labels => \@labels},
  );
}

sub aex {
  my $quoter = shift;
  my $ua     = $quoter->user_agent();
  my $agent  = $ua->agent;
  $ua->agent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36');

  my %info;
  my $url;
  my $reply;

  foreach my $symbol (@_) {
    my $isin = undef;

#    eval {
      my $search = "https://live.euronext.com/en/search_instruments/$symbol";
      $reply  = $ua->get($search);

      ### Search: $search, $reply->code

      if (not defined $reply->previous) {
        # Got a search page
        my $widget = scraper {
          process 'table#awl-lookup-instruments-directory-table a', 'link[]' => '@href';
        };

        my $result = $widget->scrape($reply);

        # die "Failed to find $symbol" unless exists $result->{link} and @{$result->{link}} > 0;
        unless (exists $result->{link} and @{$result->{link}} > 0) {
            $info{$symbol, 'success'} = 0;
            $info{$symbol, 'errormsg'} = 'Cannot find symbol ' . $symbol;
            next;
        }

        # Loop through linkarray. Skip links containing the string
        # "product/indices"
        for my $newlink (@{$result->{link}}) {
            ### NewLink: $newlink
            if ( $newlink !~ /product\/indices/i ) {
                $url = $newlink;
                ### Setting URL: $url
                last;
            }
        }

        # die "Failed to find isin" unless $url->as_string =~ m|/([A-Za-z0-9]{12}-[A-Za-z]+)/|;
        unless (defined($url) && $url->as_string =~ m|/([A-Za-z0-9]{12}-[A-Za-z]+)/|) {
            $info{$symbol, 'success'} = 0;
            $info{$symbol, 'errormsg'} = 'Cannot find ISIN for ' . $symbol;
            next;
        } else {
            $isin = uc($1);
        }
        
      }
      else {
        # Redirected
        my $widget = scraper {
          process 'a', 'redirect' => '@href';
        };

        my $result = $widget->scrape($reply->previous->content);

        # die "Failed to find $symbol in redirect" unless exists $result->{redirect};
        unless (exists $result->{redirect}) {
            $info{$symbol, 'success'} = 0;
            $info{$symbol, 'errormsg'} =
                'Cannot find symbol ' . $symbol . ' in redirect';
            next;
        }
        
        my $url = $result->{redirect};
        
        # die "Failed to find isin in redirect" unless $url =~ m|/([A-Za-z0-9]{12}-[A-Za-z]+)|;
        unless ($url =~ m|/([A-Za-z0-9]{12}-[A-Za-z]+)|) {
            $info{$symbol, 'success'} = 0;
            $info{$symbol, 'errormsg'} =
                'Cannot find ISIN for ' . $symbol . ' in redirect';
            next;
        }
        
        $isin = uc($1);
        ### ISIN: $isin

      }
  
      # die "No isin set" unless defined $isin;
      unless (defined $isin) {
          $info{$symbol, 'success'} = 0;
          $info{$symbol, 'errormsg'} = 'No ISIN set for ' . $symbol;
          next;
      }

#    };	# End eval
    
    if ($@) {
      my $error = "Search failed: $@";
      $info{$symbol, 'success'}  = 0;
      $info{$symbol, 'errormsg'} = trim($error);
      next;
    }

#    eval {
      my $url   = "https://live.euronext.com/en/ajax/getDetailedQuote/$isin";
      my %form  = (theme_name => 'euronext_live');
      $reply = $ua->post($url, \%form);

      ### Header : $url, $reply->code
      ### Content: $reply->content

      my $widget = scraper {
        process 'h1#header-instrument-name strong', 'name' => ['TEXT', sub {trim($_)}];
        process 'span#header-instrument-price', 'last' => ['TEXT', sub {trim($_)}];
        # process 'div.head_detail_bottom div.col span, div.head_detail > div > div:last-child', 'date' => ['TEXT', sub {trim($_)}];
        # process 'div.ml-2 last-price-date-time', 'date' => ['TEXT', sub {trim($_)}];
        process 'div.ml-2.last-price-date-time', 'date' => ['TEXT', sub {trim($_)}];
      };

      my $header = $widget->scrape($reply);
      ### Header getDetailedQuote: $header

      $url = "https://live.euronext.com/en/intraday_chart/getDetailedQuoteAjax/$isin/full";

      $reply  = $ua->get($url);
      $widget = scraper {
        process 'div.table-responsive td:first-child, div.table-responsive td:first-child + td', 'data[]' => ['TEXT', sub {trim($_)}];
      };

      ### Body : $url, $reply->code

      my $body = $widget->scrape($reply);

      # die "Failed to find detailed quote table" unless exists $body->{data};
      unless (exists $body->{data}) {
          $info{$symbol, 'success'} = 0;
          $info{$symbol, 'errormsg'} = 'Failed to find detailed quote table';
          next;
      }
     
      my %table = @{$body->{data}};

      $info{$symbol, 'success'}  = 1;
      $info{$symbol, 'currency'} = $table{Currency};
      $info{$symbol, 'volume'}   = $table{Volume};
      $info{$symbol, 'volume'}   =~ s/,//g;
      $info{$symbol, 'open'}     = $table{Open};
      $info{$symbol, 'high'}     = $table{High};
      $info{$symbol, 'low'}      = $table{Low};

      $info{$symbol, 'name'}     = $header->{name};
      $info{$symbol, 'isin'}     = $1 if $isin =~ /([A-Z0-9]{12})/;
      $info{$symbol, 'last'}     = $header->{last};

      $quoter->store_date(\%info, $symbol, {eurodate => $1}) if  $header->{date} =~ m|([0-9]{2}/[0-9]{2}/[0-9]{4})|;
#    };	# End eval

    if ($@) {
      my $error = "Fetch/Parse failed: $@";
      $info{$symbol, 'success'}  = 0;
      $info{$symbol, 'errormsg'} = trim($error);
      next;
    }
  }

  $ua->agent($agent);

  return wantarray() ? %info : \%info;
}

1;

=head1 NAME

Finance::Quote::AEX - Obtain quotes from Amsterdam Euronext eXchange

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = $q->fetch("aex", "AMG");   # Only query AEX
    %info = $q->fetch("dutch", "AMG"); # Failover to other sources OK

=head1 DESCRIPTION

This module fetches information from https://live.euronext.com. Stocks and bonds
are supported.

This module is loaded by default on a Finance::Quote object. It's also possible
to load it explicitly by placing 'aex' in the argument list to
Finance::Quote->new().

=head1 LABELS RETURNED

The following labels may be returned: currency date high isin isodate last low
name open success symbol volume. 

=head1 Terms & Conditions

Use of live.euronext.com is governed by any terms & conditions of that site.

Finance::Quote is released under the GNU General Public License, version 2,
which explicitly carries a "No Warranty" clause.

=cut
