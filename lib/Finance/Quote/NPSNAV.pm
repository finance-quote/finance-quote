#!/usr/bin/perl -w
# vi: set ts=2 sw=2 noai expandtab ic showmode showmatch:  
#
#    Copyright (C) 2026, Kalpesh Patel <wrackguard+f_and_q@gmail.com>
#
#    This file is part of Finance::Quote.
#
#    Finance::Quote is free software: you can redistribute it and/or
#    modify it under the terms of the GNU General Public License as
#    published by the Free Software Foundation, either version 2 of
#    the License, or (at your option) any later version.
#
#    Finance::Quote is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#    General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with Finance::Quote.
#    If not, see <https://www.gnu.org/licenses/>.
#
# This code is derived from TSP.pm module.

package Finance::Quote::NPSNAV;

use strict;

use constant DEBUG => $ENV{DEBUG} || $ENV{NPSNAV_DEBUG};
use if DEBUG, 'Smart::Comments', '###';

use vars qw( $NPSNAV_URL $NPSNAV_MAIN_URL @HEADERS );

use LWP::UserAgent;
use HTTP::Request::Common;
use POSIX;
use JSON qw(decode_json);

# VERSION

# URLs of where to obtain information
$NPSNAV_URL      = 'https://npsnav.in/api/detailed';
$NPSNAV_MAIN_URL = 'http://npsnav.in';
@HEADERS      = ('user-agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/102.0.5005.61 Safari/537.36');

our $DISPLAY    = 'NPSNAV - India National Pension System';
our @LABELS     = qw/name lastupdated isodate currency nav/;
our $METHODHASH = {subroutine => \&npsnav,
                   display    => $DISPLAY,
                   labels     => \@LABELS};

sub methodinfo {
  return (
      npsnav => $METHODHASH,
  );
}

sub labels {
  my %m = methodinfo();
  return map {$_ => [@{$m{$_}{labels}}] } keys %m;
}

sub methods {
  my %m = methodinfo();
  return map {$_ => $m{$_}{subroutine} } keys %m;
}

sub format_name {
  my $name = shift;
  $name =~ s/ //g;
  $name = lc($name);

  return $1 if $name =~ /^(.)fund$/;
  return $name;
}

sub currency_fields {
    return qw/nav 1D 1M 1Y 3M 3Y 5Y 6M 7D/;
}

# ==============================================================================
sub npsnav {
  my $quoter = shift;
  my @symbols = @_;

  return unless @symbols;

  my %info;

  my $ua    = $quoter->user_agent;
  
##
##  https://npsnav.in/api/detailed/SM001001
##
##  {
##  "Last Updated": "01-10-2024",
##  "PFM Code": "PFM001",
##  "PFM Name": "SBI PENSION FUNDS PRIVATE LIMITED",
##  "Scheme Code": "SM001001",
##  "Scheme Name": "SBI PENSION FUND SCHEME - CENTRAL GOVT",
##  "NAV": "46.7686",
##  "1D": "0.10",
##  "7D": "0.13",
##  "1M": "1.34",
##  "3M": "3.51",
##  "6M": "6.73",
##  "1Y": "13.98",
##  "3Y": "8.16",
##  "5Y": "9.23"
##  }
##

  foreach my $symbol (@symbols) {
    my $url   = "$NPSNAV_URL/$symbol";
    my $reply = $ua->get($url, @HEADERS);
    my $body = $reply->content;
    my $success = $reply->is_success;

    ### [<now>] url  : $url
    ### [<now>] reply: $reply
    
    if ($success) {
      $info{$symbol, 'success'} = 1;

      my $json_data = decode_json ($body);
      while (my ($key, $value) = each %$json_data) {
        my $mkey = $key;
        if ($mkey eq 'NAV') {
          $mkey = 'nav';
        }
        $info{$symbol, $mkey} = $value;
      }
      
      $quoter->store_date(\%info, $symbol, {eurodate => $json_data->{"Last Updated"} =~ s/-/\//gr}); # not sure if dash separator is correct, but it works for now
      $info{$symbol, 'method'} = 'npsnav';
      $info{$symbol, 'source'} = $NPSNAV_MAIN_URL;
      $info{$symbol, 'symbol'} = $symbol;
      $info{$symbol, 'currency'} = 'INR';
    } else {
      $info{$symbol, "success"}  = 0;
      $info{$symbol, "errormsg"} = "NPSNAV fetch failed. No data for $symbol. ".$reply->status_line;
      ### Failure: %info
    }
  }

  return %info if wantarray;
  return \%info;
}
1;

=head1 NAME

Finance::Quote::NPSNAV - Obtain fund prices for India's National Pension Scheme (NPS) funds.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = $q->fetch('npsnav','SM001001');       #get quotes for SBI PENSION FUND SCHEME - CENTRAL GOVT

=head1 DESCRIPTION

This module fetches NAV for pension schemes from the India's National Pension System.

    http://npsnav.in

=head1 LABELS RETURNED

The following labels are returned by Finance::Quote::NPSNAV :

    lastupdated               latest date, eg. "21/02/10"
    isodate                   latest date, eg. "2010-02-21"
    nav                       latest available price, eg. "16.1053"
    currency                  "INR"
    method                    "npsnav"
    source                    NPSNAV URL
    1D 7D 1M 3M 6M 1Y 3Y 5Y   performance metrics 1-day to 5-year 

=cut
