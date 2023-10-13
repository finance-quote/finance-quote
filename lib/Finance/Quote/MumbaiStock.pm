#!/usr/bin/perl -w

#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 3 of the License, or
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

#    Version using IndiaMutual.pm as an base

package Finance::Quote::MumbaiStock;

use strict;
use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use LWP::UserAgent;
use HTTP::Request::Common;
use HTTP::Status;
use IO::Uncompress::Unzip qw(unzip $UnzipError) ;

# VERSION

use vars qw( $MSTK_URL $MSTK_ZIP $MSTK_PRC_LIST $MSTK_MAIN_URL $MSTK_EQ_ZIPNAME $MSTK_CSV);

sub methods { return (mumbaistock => \&mstkindia,
                      mstkindia => \&mstkindia); }

{
    my @labels = qw/method source link name currency date isodate nav rprice sprice/;
    sub labels { return (mumbaistock => \@labels,
                         mstkindia => \@labels); }
}

#
# =======================================================================

sub mstkindia   {
    my $quoter = shift;
    my @symbols = @_;

    # Make sure symbols are requested
    return unless @symbols;

	# Break the localtime for $today
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
	my $today = time();
	my $cachedir = $ENV{TMPDIR} // $ENV{TEMP} // '/tmp/';
	$MSTK_MAIN_URL = ("https://www.bseindia.com/");
	$MSTK_CSV = sprintf("BSE_EQ_BHAVCOPY.csv");
	$MSTK_PRC_LIST = $cachedir.$MSTK_CSV;
	
    # Local Variables
    my %fundquote;
    my($ua, $url, $reply, $proceed, $errormsg);

	$proceed = 0;
	my $attempts = 1;
	#if $attempts > 5, then no data could be retrieved. Done to take care of network issues
	
	while ($proceed == 0) {
		
		# Break down today's date into it's elements
		($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($today);

		# URLs of where to obtain information. Setup Variables for file names
		$MSTK_EQ_ZIPNAME = sprintf("BSE_EQ_BHAVCOPY_%02d%02d%4d.ZIP", $mday, $mon+1, $year-100+2000);
		$MSTK_URL = sprintf("https://www.bseindia.com/download/BhavCopy/Equity/BSE_EQ_BHAVCOPY_%02d%02d%04d.ZIP", $mday, $mon+1, $year-100+2000);
		$MSTK_ZIP = $cachedir.$MSTK_EQ_ZIPNAME;
		
		#Fetch the file using user_agent
		$ua = $quoter->get_user_agent();        #Replaced user_agent by get_user_agent
		$ua->agent('');							#make user_agent as empty for a conducive server response
		$url = "$MSTK_URL";
		$reply = $ua->mirror($url, $MSTK_ZIP);
		
		if ($reply->is_success) {
			$proceed = 1;
			last;
		} else {
			$proceed = 0;
			$errormsg = "HTTP failure : " . $reply->status_line;
		}
		
		if ($reply->code == RC_NOT_MODIFIED) {
			$proceed = 1;
			last;
		} else {
			$proceed = 0;
			$errormsg = "HTTP failure : " . $reply->status_line;
		}
		
		if ($proceed == 1) {
			last;
		}
		
		#Attempts checking
		$attempts = $attempts + 1;
		if ($attempts > 5) {
			$proceed = 0;
			last;
		}

		$today = $today - (60*60*24);		# $today minus one day if reply is not success
	}
	
	#Unzip if $proceed = 1
	if ($proceed == 1) {
		my $input = $MSTK_ZIP;
		my $output = $MSTK_PRC_LIST;        
		unzip $input => $output or die "unzip failed: $UnzipError\n";
	}
	
    # Make sure something is returned.
    unless ($proceed == 1) {
	    foreach my $symbol (@symbols) {
	        $fundquote{$symbol,"success"} = 0;
	        $fundquote{$symbol,"errormsg"} = "HTTP failure";
	    }
	    return wantarray ? %fundquote : \%fundquote;
    }
    
    #Open the stock prices bhav copy csv file
    my $prc_fh;
    open $prc_fh, '<', $MSTK_PRC_LIST or die "Unexpected error in opening file: $!\n";
    
    # Create a hash of all stocks requested
    my %symbolhash;
    foreach my $symbol (@symbols)
    {
        $symbolhash{$symbol} = 0;
    }
    my $csvhead;
    my @headhash;

    while (<$prc_fh>) {		
		next if !/\,/;
		chomp;
		s/\r//;

		my ($isin, $ticker, $symbol1, $name, $group, $open, $high, $low, $close, $last, $prevclose, $trdvol, $trfval, $trdate, $trexec, $insttype, $corpevt, $rptdate, $trdorg, $mktpd, $instrid, $instrnm, $f2weekh, $f2weekl, $uom, $sttlprc, $avgprc, $ccy, $rsvd1, $rsvd2, $rsvd3, $rsvd4) = split /\s*\,\s*/;
        
	    my ($symbol);
	    if (exists $symbolhash{$symbol1}) {
	        $symbol = $symbol1;
	    }
	    else {
			next;
		}
	    
	    $fundquote{$symbol, "symbol"} = $symbol;
	    $fundquote{$symbol, "currency"} = "INR";
	    $fundquote{$symbol, "source"} = $MSTK_MAIN_URL;
	    $fundquote{$symbol, "link"} = $url;
	    $fundquote{$symbol, "method"} = "mstkindia";
	    $fundquote{$symbol, "name"} = $name;
	    $fundquote{$symbol, "nav"} = $close;
   	    #date format
	    $quoter->store_date(\%fundquote, $symbol, {eurodate => $trdate});
	    $fundquote{$symbol, "success"} = 1;
    }
    close($prc_fh);

    foreach my $symbol (@symbols) {
		unless (exists $fundquote{$symbol, 'success'}) {
			$fundquote{$symbol, 'success'} = 0;
			$fundquote{$symbol, 'errormsg'} = 'Stock not found.';
		}
    }
    return wantarray ? %fundquote : \%fundquote;
}

1;

=head1 NAME

Finance::Quote::MumbaiStock  - Obtain Indian stock prices from bseindia.com standardized file bhavcopy at https://www.bseindia.com/download/BhavCopy/Equity/BSE_EQ_BHAVCOPY_DDMMYYYY.ZIP where DD = date, MM = month and YYYY = year.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %stockinfo = $q->fetch("mumbaistock", "mstkindia-code"); # Can
failover to other methods
    %stockinfo = $q->fetch("mstkindia", "mstkindia-code"); # Use this
module only.

    # NOTE: currently no failover methods exist for mumbaistock

=head1 DESCRIPTION

This module obtains information about Indian stock prices from the
Bombay Stock Exchange website https://www.bseindia.com/.
The information source "mumbaistock" can be used
if the source of prices is irrelevant, and "mstkindia" if you
specifically want to use information downloaded from bseindia.com.

=head1 MSTKINDIA CODE/ISIN

In India, bseindia stocks have a ISIN and also a code.
You can use the code if you can't find the ISIN. This module uses the code . Doing a stock search on https://wwww.bseindia.com displays the ISIN as well as the code. Eg:
https://www.bseindia.com/stock-share-price/abb-india-limited/abb/500002/
For ABB India Limited, the code is 500002 and it's ISIN is  INE117A01022. This module uses the code i.e. 500002.

=head1 LABELS RETURNED

Information available from bseindia may include the following labels:
isin, ticker, symbol1, name, group, open, high, low, close, last, prevclose, 
trdvol, trfval, trdate, trexec, insttype, corpevt, rptdate, trdorg, mktpd, 
instrid, instrnm, f2weekh, f2weekl, uom, sttlprc, avgprc, ccy, rsvd1, rsvd2, 
rsvd3, rsvd4)

Field details are available in a notification on the bseindia website
https://www.bseindia.com/markets/MarketInfo/DownloadAttach.aspx?id=20221201-52&attachedId=528afdfb-749b-4636-80fb-7576b91f2f2c

=head1 NOTES

MSTK provides a link to download a text file containing all the
prices. This file is mirrored in a local file /tmp/BSE_EQ_BHAVCOPY_%02d%02d%4d.ZIP
and BSE_EQ_BHAVCOPY.csv. The local mirror serves only as a cache and can be safely removed.

=head1 TERMS & CONDITIONS

Use of https://www.bseindia.com is governed by any terms & conditions of that site.

Finance::Quote is released under the GNU General Public License, version 2,
which explicitly carries a "No Warranty" clause.

=head1 SEE ALSO

BSE india website - https://www.bseindia.com/

Finance::Quote

=cut
