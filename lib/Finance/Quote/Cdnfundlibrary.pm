#!/usr/bin/perl -w

#  Cdnfundlibrary.pm
#
#  Version 0.6 retrieve more data via different fundlibrary.com url
#  Version 0.5 made functional again
#  Version 0.4 fixed up multiple lookup  (March 3, 2001)
#  Version 0.3 fixed up yield lookup
#  Version 0.2 functional with Finance::Quote - added error-checking
#  Version 0.1 pre trial of parsing of info from www.fundlibrary.com


package Finance::Quote::Cdnfundlibrary;
require 5.004;

use strict;

use vars qw($VERSION $FUNDLIB_URL $FUNDLIB_MAIN_URL);

use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;

$VERSION = '0.6';

# URLs of where to obtain information.

$FUNDLIB_URL =
("http://www.fundlibrary.com/funds/db/_fundcard.asp?t=2&id=");
$FUNDLIB_MAIN_URL=("http://www.fundlibrary.com");

sub methods { return (canadamutual => \&fundlibrary,
                       fundlibrary => \&fundlibrary); }

{
    my @labels = qw/method source link name currency last date isodate nav yield
		    price net p_change/;
    sub labels { return (canadamutual => \@labels,
                          fundlibrary => \@labels); }
}

#
# =======================================================================

sub fundlibrary   {
    my $quoter = shift;
    my @symbols = @_;

    # Make sure symbols are requested  
    ##CAN exit more gracefully - add later##

    return unless @symbols;

    # Local Variables
    my(%fundquote, $mutual);
    my($ua, $url, $reply, $ts, $row, $rowhd, $te, @rows, @ts);

    $ua = $quoter->user_agent;

    foreach (@symbols) {

      $mutual = $_;
      $url = "$FUNDLIB_URL$mutual";
      $reply = $ua->request(GET $url);
      $te = new HTML::TableExtract(headers => ["Date", "NAVPS"],
				   slice_columns => 0);

      # Make sure something is returned  ##CAN exit more gracefully - add later##
      return unless ($reply->is_success);

      $te->parse($reply->content);

      # Check for a page without tables
      # This gets returned when a bad symbol name is given
      unless ( $te->tables > 0 ) 
      {
	$fundquote {$mutual,"success"} = 0;
	$fundquote {$mutual,"errormsg"} = "Fund name $mutual not found";
	next;
      } 
     
      # Fund name
      $reply->content =~ m#<div\s+class="tSmallTitle">([^<]+)</div>#;
      $fundquote {$mutual, "name"} = $1;

      @rows = $te->rows;
      if(@rows) {
          $fundquote {$mutual, "symbol"} = $mutual;
          $fundquote {$mutual, "currency"} = "CAD";
          $fundquote {$mutual, "source"} = $FUNDLIB_MAIN_URL;
          $fundquote {$mutual, "link"} = $url;
          $fundquote {$mutual, "method"} = "fundlibrary";

          # Fund price and date
	  $row = $rows[1];
          $fundquote {$mutual, "price"} =  $$row[2];
          $fundquote {$mutual, "nav"} = $$row[2];
          $fundquote {$mutual, "last"} = $$row[2];
          $fundquote {$mutual, "net"} = $$row[3];
          $fundquote {$mutual, "p_change"} = $$row[4];

	  $quoter->store_date(\%fundquote, $mutual, {usdate => $$row[0]});

          # Assume things are fine here.
          $fundquote {$mutual, "success"} = 1;

          # Performance yield
          $fundquote {$mutual, "yield"} = $$row[5] if ($$row[5] ne "--");
      }
      else {
          $fundquote {$mutual, "success"} = 0;
          $fundquote {$mutual, "errormsg"} = "Fund Not Found";
      }


   } #end symbols

   return %fundquote if wantarray;
   return \%fundquote;

}

1;

=head1 NAME

Finance::Quote::Cdnfundlibrary  - Obtain mutual fund prices from
www.fundlibrary.com

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %stockinfo = $q->fetch("canadamutual","fundlib-code"); # Can
failover to other methods
    %stockinfo = $q->fetch("fundlibrary","fundlib-code"); # Use this
module only.

    # NOTE: currently no failover methods exist for canadamutual

=head1 DESCRIPTION

This module obtains information about Canadian Mutual Fund prices from
www.fundlibrary.com.  The information source "canadamutual" can be used
if the source of prices is irrelevant, and "fundlibrary" if you
specifically want to use www.fundlibrary.com.

=head1 FUNDLIB-CODE

In Canada a mutual fund does not have a unique global symbol identifier.

This module uses an id that represents the mutual fund on an id used by
www.fundlibrary.com.  There is no easy way of fetching the id except
to jump onto the fundlibrary website, look up the fund and view the url
for clues to its id number.

=head1 LABELS RETURNED

Information available from fundlibrary may include the following labels:

exchange method link source name currency yield last nav price.  The
link
label will be a url location for a one page snapshot that fundlibrary
provides
on the fund.

=head1 SEE ALSO

Fundlibrary website - http://www.fundlibrary.com/

Finance::Quote

=cut

