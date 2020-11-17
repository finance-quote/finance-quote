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

package Finance::Quote::ZA;

use strict;
use warnings;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use LWP::UserAgent;
use Web::Scraper;
use String::Util qw(trim);

# VERSION

our @labels = qw/method source name symbol currency last date isodate high low p_change/;

sub labels {
  return ( sharenet => \@labels );
}

sub methods {
  return ( za => \&sharenet );
}

sub sharenet {
    my $quoter  = shift;
    my @symbols = @_;
    my $ua      = $quoter->user_agent();
    my %info;

    foreach my $symbol (@_) {
      eval {
        my $url   = "https://www.sharenet.co.za/jse/$symbol";
        my $reply = $ua->get($url);

        my $widget = scraper {
          process 'h1.share-chart-title', 'name' => ['TEXT', sub{trim($_)}],
          process 'h1.share-chart-title + h2', 'last' => ['TEXT', sub{$_ =~ /([0-9,.]+)/ ? $1 : '<unknown>';}],
          process 'h1.share-chart-title + h2 + div b', 'day' => ['TEXT', sub{$_ =~ /(\w{3}\s+\d+\s+\w{3}),/ ? $1 : '<unknown>';}],
        };

        my $result = $widget->scrape($reply);

        die "Failed to find $symbol" unless exists $result->{name};
     
        ### RESULT : $result
        
        $info{$symbol, 'success'}  = 1;
        $info{$symbol, 'currency'} = 'ZAR';
        $info{$symbol, 'name'}     = $result->{name};
        $info{$symbol, 'price'}    = $result->{last};
        $info{$symbol, 'price'}    =~ s/,//;

        if ($result->{day} =~ /(\d+)\s+(\w{3})/) {
          $quoter->store_date(\%info, $symbol, {day => $1, month => $2});
        }
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

Finance::Quote::ZA - Obtain South African stock and prices from
https://www.sharenet.co.za

=head1 SYNOPSIS

    use Finance::Quote;

    $q    = Finance::Quote->new;
    %info = Finance::Quote->fetch('za', 'AGL');

=head1 DESCRIPTION

This module obtains information about South African Stocks from
www.sharenet.co.za.

This module is loaded by default on a Finance::Quote object. It's also possible
to load it explicitly by placing 'za' in the argument list to
Finance::Quote->new().

=head1 LABELS RETURNED

The following labels will be returned: success currency name price date isodate.

=head1 Terms & Conditions

Use of sharenet.co.za is governed by any terms & conditions of that site.

Finance::Quote is released under the GNU General Public License, version 2,
which explicitly carries a "No Warranty" clause.

=cut

