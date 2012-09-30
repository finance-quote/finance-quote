#!/usr/bin/perl -w
#
# USFedBonds.pm
#
# 0.02 - Fix problem with looking up the correct file to select any redemption
# date back to 1992/05 (furthest back that is currently offered by treasury)
# Version 0.01 - First version of download for US treasury bond prices
# Doesn't download prices with redemption dates before June 2005 !!!!
#
# Stephen Langenhoven
# langenhoven@users.sourcesforge.net
# 2005.07.21


package Finance::Quote::USFedBonds;
require 5.004;

use strict;
use vars qw /$VERSION/ ;

use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;
use HTML::Parser;

$VERSION = '1.18' ;
my $TREASURY_MAINURL = ("http://www.publicdebt.treas.gov/");
my $TREASURY_URL = ($TREASURY_MAINURL."sav/");

sub methods {
    return (usfedbonds => \&treasury);
}


sub labels {
    my @labels = qw/method source name symbol currency last date isodate nav price/;
    return (usfedbonds => \@labels);
}


sub treasury {

    my $quoter = shift;
    my @symbols = @_;
    my %info;

#     print "[debug]: ", @symbols, "\n";

    return unless @symbols;

    my $ua = $quoter->user_agent;

    foreach my $symbol (@symbols) {

       #print STDERR "[debug]: Parsing:", $symbol, "\n";
       my ($series, $issueyear, $issuemonth) = ( $symbol =~ m!^(.)(\d{4})(\d{2})! );
       if (!defined($series) || !defined($issueyear) || !defined($issuemonth)) {
	 $info{$symbol, "success"} = 0;
	 $info{$symbol, "errormsg"} = "Parse error";
	 #printf STDERR "[debug]: Setting %s to 'Parse error'\n", $symbol;
	 next;
       }
       my ($redemptionyear, $redemptionmonth) = ( $symbol =~ m!^.{8}(\d{4})(\d{2})! );
       if (!defined($redemptionyear) || !defined($redemptionmonth)) {
	 my ($a,$b,$c,$d,$e,$f,$g);
	 ($a,$b,$c,$d,$redemptionmonth,$redemptionyear,$e,$f,$g) = localtime;
	 $redemptionmonth = $redemptionmonth + 1;
	 $redemptionyear = $redemptionyear + 1900;
	 #print "[debug]: (Setting redemption date)\n";
       }
       #print "[debug]: (Series):", $series, "\n";
       #print "[debug]: (Issue Year):", $issueyear, "\n";
       #print "[debug]: (Issue Month):", $issuemonth, "\n";
       #print "[debug]: (Redemption Year):", $redemptionyear, "\n";
       #print "[debug]: (Redemption Month):", $redemptionmonth , "\n";

        my $response;

# not so easy...need to guess what the relavant date is...
# file date will be <= the redemption date

#start at the redemption year/month and move backwards at most 12 months...
        my $fileyear = $redemptionyear;
        my $filemonth = $redemptionmonth;

        for (my $looper=1; $looper <= 12; $looper++) {

          my $url = $TREASURY_URL . "sb" . $fileyear . $filemonth . ".asc";

          #print "[debug]: ", $url, " ", $looper, "\n";

          $response = $ua->request(GET $url);

          if ($response->is_success) {
	    # Get list of monthly redemption values
	    (my $redemptionvalues) = ( $response->content =~ m!${series}${redemptionyear}${redemptionmonth}${issueyear}(.+)! );
	    if (!defined($redemptionvalues))
	      {
		$info{$symbol, "success"} = 0;
		$info{$symbol, "errormsg"} = "Date not found";
		#printf STDERR "[debug]: Setting %s to 'date not found'\n", $symbol;
		last;
	      }
	    else
	      {
		#print "[debug]: (Redemption Values) ", $redemptionvalues, "\n";
	      }

	    # Extract into a usable array format
	    (my @redemptionvalues) = ( $redemptionvalues =~ m!(.{6})!g );
	    #foreach my $redemptionvalue (@redemptionvalues) {
	    #  print "[debug]: (Redemption Value) ", $redemptionvalue, "\n";
	    #}

	    # Hopefully pop out the one I really wanted!!!  Note that $issuemonth
	    # is 1-based while the array of values is 0-based.
	    if ($redemptionvalues[$issuemonth - 1] eq "      ")
	      {
                #print "[debug]: NO PAY";
		$info{$symbol, "success"} = 0;
		$info{$symbol, "errormsg"} = "No value found";
		#printf STDERR "[debug]: Setting %s to 'no value found'\n", $symbol;
		last;
	      }

	    #
	    # GENERAL FIELDS
	    $info{$symbol, "method"} = "treasury";

	    #print "[debug]: (Month): ", $issuemonth, " Redemption Value ", $redemptionvalues[$issuemonth - 1];
	    $info{$symbol, "price"} = $redemptionvalues[$issuemonth - 1]/100;
	    $info{$symbol, "symbol"} = $symbol;
	    $info{$symbol, "currency"} = "USD";
	    $info{$symbol, "source"} = $TREASURY_MAINURL;
	    $info{$symbol, "date"} = $redemptionmonth . "/01/" . $redemptionyear;
	    $info{$symbol, "isodate"} = $redemptionyear . "-" . $redemptionmonth . "-01";
	    $info{$symbol, "version"} = "0.02";
	    $info{$symbol, "success"} = 1;
	    last;
	  } else {
	    #Decrement the month, and pad if necessary...
	    $filemonth = $filemonth - 1;
	    if ( length($filemonth) < 2 ) {
	      $filemonth = "0" . $filemonth;

	      if ($filemonth < 1) {
		$filemonth = "12";
		#Setting himself up for the year 100000 problem (short-sighted sod)
		$fileyear = $fileyear - 1;
	      }
	    }
	  }
	}
       if (!defined($info{$symbol, "success"})) {
	 $info{$symbol, "success"} = 0;
	 $info{$symbol, "errormsg"} = "Error contacting URL";
       }
     }

    return wantarray() ? %info : \%info;
}

1;

=head1 NAME

Finance::Quote::USFedBonds
Get US Federal Bond redemption values directly from the treasury at
www.publicdebt.treas.gov/sav/savvalue.htm

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    # Don't know anything about failover yet...

=head1 DESCRIPTION

Access redemption values for US Federal Bonds from the treasury.

Bonds should be identified in the following manner (as per www.piblicdebt.treas.gov/sav/savfrmat.htm):

SERIES(1)         : I/E/N/S

ISSUEDATE(6)      : YYYYMM

SEPERATOR(1)      : "."

REDEMPTIONDATE(6) : YYYYMM

e.g. E200101.200501

Would have liked to get data from this source (http://wwws.publicdebt.treas.gov/BC/SBCPrice), but I couldn't work out how to get the POST to pass the IssueDate, for some reason the <input> tags are messed on that page???

=head1 LABELS RETURNED

...

=head1 SEE ALSO

Treasury website - http://www.publicdebt.treas.gov/

Finance::Quote

=head1 AUTHOR
Stephen Langenhoven (langenhoven@users.sourceforge.net), see module ZA for further acknowledgements.

=cut
