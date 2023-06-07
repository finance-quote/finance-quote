#!/usr/bin/perl -w
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

# Version 0.1 preliminary version using Cdnfundlibrary.pm v0.4 as an example

package Finance::Quote::IndiaMutual;

use strict;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use vars qw( $AMFI_URL $AMFI_NAV_LIST $AMFI_MAIN_URL);

use LWP::UserAgent;
use HTTP::Request::Common;
use HTTP::Status;
use IO::String;

# VERSION

# URLs of where to obtain information.

$AMFI_MAIN_URL = ("http://www.amfiindia.com/");
$AMFI_URL = ("https://www.amfiindia.com/spages/NAVAll.txt");

sub methods { return (indiamutual => \&amfiindia,
                      amfiindia => \&amfiindia); }

{
    my @labels = qw/method source link name currency date isodate nav/;
    sub labels { return (indiamutual => \@labels,
                         amfiindia => \@labels); }
}

#
# =======================================================================

sub amfiindia   {
    my $quoter = shift;
    my @symbols = @_;

    # Make sure symbols are requested
    ##CAN exit more gracefully - add later##

    return unless @symbols;

    # Local Variables
    my %fundquote;
    my($ua, $url, $reply);

    $ua = $quoter->user_agent;

    $url = "$AMFI_URL";

    ### cache : $AMFI_NAV_LIST
  
    $reply = $ua->get($url);

    # Make sure something is returned
    unless ($reply->is_success or $reply->code == RC_NOT_MODIFIED) {
      foreach my $symbol (@symbols) {
          $fundquote{$symbol,"success"} = 0;
          $fundquote{$symbol,"errormsg"} = "HTTP failure";
      }
      return wantarray ? %fundquote : \%fundquote;
    }

    # Attach body of response to IO::String object for file-like processing
    my $nav_fh = IO::String->new($reply->content)
;
    # Create a hash of all stocks requested
    my %symbolhash;
    foreach my $symbol (@symbols)
    {
        $symbolhash{$symbol} = 0;
    }

    #Scheme Code;ISIN Div Payout/ ISIN Growth;ISIN Div Reinvestment;Scheme Name;Net Asset Value;Date
    while (<$nav_fh>) {
      next if !/\;/;
      chomp;
      s/\r//;
          my ($symbol1, $symbol2, $symbol3, $name, $nav, $date) = split /\s*\;\s*/;
      my $symbol;
      if (exists $symbolhash{$symbol1}) {
          $symbol = $symbol1;
      }
      elsif(exists $symbolhash{$symbol2}) {
          $symbol = $symbol2;
      }
      elsif(exists $symbolhash{$symbol3}) {
          $symbol = $symbol3;
      }
      else {
          next;
      }
      $fundquote{$symbol, "symbol"} = $symbol;
      $fundquote{$symbol, "currency"} = "INR";
      $fundquote{$symbol, "source"} = $AMFI_MAIN_URL;
      $fundquote{$symbol, "link"} = $url;
      $fundquote{$symbol, "method"} = "amfiindia";
      $fundquote{$symbol, "name"} = $name;
      $fundquote{$symbol, "nav"} = $nav;
      $quoter->store_date(\%fundquote, $symbol, {eurodate => $date});
      $fundquote{$symbol, "success"} = 1;
    }
    close($nav_fh);

    foreach my $symbol (@symbols) {
    unless (exists $fundquote{$symbol, 'success'}) {
            $fundquote{$symbol, 'success'} = 0;
            $fundquote{$symbol, 'errormsg'} = 'Fund not found.';
        }
    }

    return wantarray ? %fundquote : \%fundquote;
}

1;

=head1 NAME

Finance::Quote::IndiaMutual  - Obtain Indian mutual fund prices from amfiindia.com

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    # Can failover to other methods
    %stockinfo = $q->fetch("indiamutual", "amfiindia-code");

    # Use this module only
    %stockinfo = $q->fetch("amfiindia", "amfiindia-code");

    # NOTE: currently no failover methods exist for indiamutual

=head1 DESCRIPTION

This module obtains information about Indian Mutual Fund prices from the
Association of Mutual Funds India website amfiindia.com.
The information source "indiamutual" can be used
if the source of prices is irrelevant, and "amfiindia" if you
specifically want to use information downloaded from amfiindia.com.

=head1 AMFIINDIA-CODE/ISIN

In India, not all funds have an ISIN. However, they do have a scheme code.
You can use those if you can't find the ISIN. See AMFI site for details.
http://www.amfiindia.com/nav-history-download

=head1 LABELS RETURNED

Information available from amfiindia may include the following labels:

=over

=item method

=item link

=item source

=item name

=item currency

=item nav

=back

The link label will be a url location for the NAV list table for all funds.

=head1 NOTES

AMFI provides a link to download a text file containing all the
L<NAVs|https://www.amfiindia.com/spages/NAVAll.txt>. It is processed
in memory using the L<IO::String> Perl module.

=head1 SEE ALSO

AMFI india website - http://www.amfiindia.com/

Finance::Quote

=cut
