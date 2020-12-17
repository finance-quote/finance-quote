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

package Finance::Quote::CSE;

use strict;
use warnings;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use LWP::UserAgent;
use JSON qw( decode_json );
use String::Util qw(trim);

# VERSION

our @labels = qw/last date isodate/;

sub labels {
  return ( cse => \@labels );
}

sub methods {
  return ( cse => \&cse );
}

sub cse {
  my $quoter  = shift;
  my @symbols = @_;
  my $ua      = $quoter->user_agent();
  my %info;

  foreach my $symbol (@_) {
    eval {
      my $url      = 'https://www.cse.lk/api/companyInfoSummery';
      my $form     = {'symbol' => $symbol};
      my $reply    = $ua->post($url, $form);
      my $search   = JSON::decode_json $reply->content;

      ### Search   : $url, $form, $reply->code
      ### Search   : $search

      my $data = $search->{reqSymbolInfo} or die('query did not return expected data');

      $info{$symbol, 'isin'}     = $data->{isin};
      $info{$symbol, 'close'}    = $data->{closingPrice};
      $info{$symbol, 'last'}     = $data->{lastTradedPrice};
      $info{$symbol, 'high'}     = $data->{hiTrade};
      $info{$symbol, 'low'}      = $data->{lowTrade};
      $info{$symbol, 'cap'}      = $data->{marketCap};
      $info{$symbol, 'name'}     = $data->{name};
      $info{$symbol, 'currency'} = 'LKR';
      $info{$symbol, 'success'} = 1;
    };
    
    if ($@) {
      my $error = "CSE failed: $@";
      $info{$symbol, 'success'}  = 0;
      $info{$symbol, 'errormsg'} = trim($error);
    }
  }

  return wantarray() ? %info : \%info;
}

1;

=head1 NAME

Finance::Quote::CSE - Obtain quotes from Colombo Stock Exchange in Sri Lanka

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch('cse', 'YORK.N0000');

=head1 DESCRIPTION

This module fetches information from the Colombo Stock Exchange (CSE)
in Sri Lanka http://www.cse.lk.

This module is loaded by default on a Finance::Quote object. It's also possible
to load it explicitly by placing 'CSE' in the argument list to
Finance::Quote->new().

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::CSE :
isin name currency date isodate ask close high low open volume success

=head1 TERMS & CONDITIONS

Use of www.cse.lk is governed by any terms & conditions of that site.

Finance::Quote is released under the GNU General Public License, version 2,
which explicitly carries a "No Warranty" clause.

=cut

