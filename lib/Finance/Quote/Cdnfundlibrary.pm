#!/usr/bin/perl -w

#  Cdnfundlibrary.pm
#
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

$VERSION = '0.2';

# URLs of where to obtain information.

$FUNDLIB_URL =
("http://www.fundlibrary.com/FundCard/FundCard_TFL.cfm?FundID=");
$FUNDLIB_MAIN_URL=("http://www.fundlibrary.com");

sub methods { return (canadamutual => \&fundlibrary,
                       fundlibrary => \&fundlibrary); }

{
    my @labels = qw/method source link name currency last date nav yield
price/;
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
    my($ua, $url, $reply, $ts, $row, $rowhd, $te);
#    my $te = new HTML::TableExtract();

    $ua = $quoter->user_agent;

    foreach (@symbols) {

      $mutual = $_;
      $url = "$FUNDLIB_URL$mutual";
      $reply = $ua->request(GET $url);
      $te = new HTML::TableExtract();

      # Make sure something is returned  ##CAN exit more gracefully -
add later##
      return unless ($reply->is_success);

      $te->parse($reply->content);

      # Fund name
      $ts = $te->table_state(0,1);
      if($ts) {
          ($row) = $ts->rows;
          $fundquote {$mutual, "name"} = $$row[0];

          $fundquote {$mutual, "currency"} = "CAD";
          $fundquote {$mutual, "source"} = $FUNDLIB_MAIN_URL;
          $fundquote {$mutual, "link"} = $url;
          $fundquote {$mutual, "method"} = "fundlibrary";

          # Fund price and date
          $ts = $te->table_state(2,1);
          ($row) = $ts->rows;
          if ($$row[1] =~ /^\$.+as of/) {
              $$row[1] =~ /(\d+\.\d+)/g;
              $fundquote {$mutual, "price"} =  $1;
              $fundquote {$mutual, "nav"} = $1;
              $fundquote {$mutual, "last"} = $1;

              $$row[1] =~ /(\w+) (\d{1,2})\, (\d{4})/g;
              $fundquote {$mutual, "date"} =  $1.' '.$2.', '.$3;
          }
          else {
              $fundquote {$mutual, "success"} = 0;
              $fundquote {$mutual, "errormsg"} = "Parse error retrieving
price and date";
          }

          # Performance yield
          ### Fix up by looking for headers instead

          $ts = $te->table_state(2,3);
          ($rowhd, $row) = $ts->rows;
          if ($rowhd && $row) {
              if ($$row[1] =~ /%/ && $$rowhd[1] =~ /Performance/) {
                  $$row[1] =~ s/ //g;
                  $fundquote {$mutual, "yield"} = $$row[1];
              }
          }
          else {
              $ts = $te->table_state(2,4);
              ($rowhd, $row) = $ts->rows;
              if ($rowhd && $row) {
                  if ($$row[1] =~ /%/ && $$rowhd[1] =~ /Performance/) {
                      $$row[1] =~ s/ //g;
                      $fundquote {$mutual, "yield"} = $$row[1];
                  }
              }
              else {
                  $fundquote {$mutual, "yield"} = "NA";
              }
          }
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

