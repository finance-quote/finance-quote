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

package Finance::Quote::BSEIndia;

use strict;
use POSIX qw(strftime);
#use IO::Uncompress::Unzip qw(unzip $UnzipError);

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments', '###';

# VERSION

use vars qw($BSE_URL);
$BSE_URL = "https://www.bseindia.com";

sub methods { return ( 'india' => \&bseindia,
                       'bseindia' => \&bseindia ); }

sub labels {
    my @labels = qw/close last high low open prevclose exchange name/;
    return (
    india => \@labels,
    bseindia => \@labels
    );
}

sub bseindia {
    my $quoter = shift;
    my @symbols = @_;
    return unless @symbols;

    my (%info, $errormsg, $fh, $ua, $url, $reply);
	my $output;
	my @array;
	my $meuradate;

    $ua = $quoter->user_agent;
    # Set the ua to be blank. Server blocks default useragent.
    $ua->agent('');

    # Try to fetch last 10 days
    for (my ($days, $now) = (0, time()); $days < 10; $days++) {
        # Ex: https://www.bseindia.com/download/BhavCopy/Equity/BhavCopy_BSE_CM_0_0_0_20240718_F_0000.CSV
        my @lt = localtime($now - $days*24*60*60);
        my ($date, $url, $req, $output);	# added $req, $output for fileless
        
        $date = strftime "%Y%m%d", @lt;
        $url = sprintf("https://www.bseindia.com/download/BhavCopy/Equity/BhavCopy_BSE_CM_0_0_0_%s_F_0000.CSV", $date);

        $req = HTTP::Request->new(GET => $url);     #added for fileless
        $reply = $ua->request($req);
        #print "$url", $reply->is_success, $reply->status_line, "\n"; #DEBUG
        if ($reply->is_success or $reply->code == 304) {
            last;
        }
    }

    if (!$reply->is_success  and  $reply->code != 304) {
        $errormsg = "HTTP failure : " . $reply->status_line;
    }

    if (!$errormsg) {
		#Does not use temp files. Fileless into variable $output
		#There is no zip file anymore
		#@array = split("\n", $output);
		@array = split("\n", $reply->content);
    }

    if ($errormsg) {
        foreach my $symbol (@symbols) {
			$info{$symbol, "success"} = 0;
			$info{$symbol, "errormsg"} = $errormsg;
		}
		return wantarray() ? %info : \%info;
    }

    # Create a hash of all stocks requested
    my %symbolhash;
    foreach my $symbol (@symbols)
    {
		$symbolhash{$symbol} = 0;
    }
    my $csvhead;
    my @headhash;

    # TradDt,BizDt,Sgmt,Src,FinInstrmTp,FinInstrmId,ISIN,TckrSymb,SctySrs,XpryDt,FininstrmActlXpryDt,StrkPric,OptnTp,FinInstrmNm,OpnPric,HghPric,LwPric,ClsPric,LastPric,PrvsClsgPric,UndrlygPric,SttlmPric,OpnIntrst,ChngInOpnIntrst,TtlTradgVol,TtlTrfVal,TtlNbOfTxsExctd,SsnId,NewBrdLotQty,Rmks,Rsvd1,Rsvd2,Rsvd3,Rsvd4
    
    $csvhead = $array[0];

    @headhash = split /\s*,s*/, $csvhead;
    foreach (@array) {
		my @data = split(",", $_);
		my %datahash;
		my $symbol;
		@datahash{@headhash} = @data;
    
		if (exists $symbolhash{$datahash{"FinInstrmId"}}) {
			$symbol = $datahash{"FinInstrmId"};
		}
		elsif(exists $symbolhash{$datahash{"ISIN"}}) {
			$symbol = $datahash{"ISIN"};
		}
		else {
			next;
		}
    
		$info{$symbol, 'symbol'} = $symbol;
		$info{$symbol, 'close'} = $datahash{"ClsPric"};
		$info{$symbol, 'last'} = $datahash{"LastPric"};
		$info{$symbol, 'high'} = $datahash{"HghPric"};
		$info{$symbol, 'low'} = $datahash{"LwPric"};
		$info{$symbol, 'open'} = $datahash{"OpnPric"};
		$info{$symbol, 'prevclose'} = $datahash{"PrvsClsgPric"};
		$info{$symbol, 'name'} = $datahash{"FinInstrmNm"};
		$quoter->store_date(\%info, $symbol, {isodate => $datahash{"TradDt"}});
		$info{$symbol, 'method'} = 'bseindia';
		$info{$symbol, 'currency'} = 'INR';
		$info{$symbol, 'exchange'} = 'BSE';
		$info{$symbol, 'success'} = 1;
    }

    foreach my $symbol (@symbols) {
        unless (exists $info{$symbol, 'success'}) {
			### Not Found: $symbol
			$info{$symbol, 'success'} = 0;
			$info{$symbol, 'errormsg'} = 'Stock not found on BSE.';
		}
    }

    return wantarray ? %info : \%info;
}


1;


=head1 NAME

Finance::Quote::BSEIndia - Obtain quotes from BSE (India).

=head1 SYNOPSIS

  use Finance::Quote;

  $q = Finance::Quote->new();

  %info = $q->fetch('bseindia', 'INE001A01036'); # Only query BSE.
  %info = $q->fetch('india', 'INE001A01036'); # Failover to other sources OK.

=head1 DESCRIPTION

This module obtains information about shares listed on the BSE (India).
Source is the daily bhav copy (zipped CSV).

This module provides both the "bseindia" and "india" fetch methods. Please use the "india" fetch method if you wish to have failover with other sources for Indian stocks (such as NSE).

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::BSEIndia:
close, last, high, low, open, prevclose, exchange, name

=head1 SEE ALSO

BSE (formerly known as Bombay Stock Exchange Ltd.), http://www.bseindia.com/

=cut
