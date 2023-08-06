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

package Finance::Quote::NSEIndia;
require 5.010;

use strict;
use POSIX qw(strftime);
use IO::Uncompress::Unzip qw(unzip $UnzipError);

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments', '###';

# VERSION

use vars qw($NSE_MAIN_URL $NSE_URL);
$NSE_MAIN_URL = "https://www.nseindia.com";
$NSE_URL = "https://archives.nseindia.com";

my $cachedir = $ENV{TMPDIR} // $ENV{TEMP} // '/tmp/';
my $NSE_ZIP = $cachedir.'nseindia.zip';
my $NSE_CSV = $cachedir.'nseindia.csv';

sub features() {
    return {'description' => 'Fetch quotes from NSE India'};
}

sub methods { return ( 'india' => \&nseindia,
                       'nseindia' => \&nseindia ); }

sub labels {
    my @labels = qw/close last high low open prevclose exchange/;
    return (
    india => \@labels,
    nseindia => \@labels
    );
}

sub nseindia {
    my $quoter = shift;
    my @symbols = @_;
    return unless @symbols;

    my (%info, $errormsg, $fh, $ua, $url, $reply);
	my $output;
    my @array;

    $ua = $quoter->user_agent;
    # Disable redirects - server redirects instead of 404.
    $ua->requests_redirectable([]);

    # Set the ua to be blank. Server blocks default useragent.
    $ua->agent('');
    
    my %mnames = ('01' => 'JAN', '02' => 'FEB', '03' => 'MAR', '04' => 'APR', '05' => 'MAY', '06' => 'JUN',
          '07' => 'JUL', '08' => 'AUG', '09' => 'SEP', '10' => 'OCT', '11' => 'NOV', '12' => 'DEC');
    # Try to fetch last 10 days
    for (my ($days, $now) = (0, time()); $days < 10; $days++) {
        # Ex: https://archives.nseindia.com/content/historical/EQUITIES/2020/APR/cm23APR2020bhav.csv.zip
        my @lt = localtime($now - $days*24*60*60);
        my ($day, $month, $year, $url, $req, $output);
        $day = strftime "%d", @lt;
        $month = $mnames{strftime "%m", @lt}; # Can't use %b as it's locale dependent.
        $year = strftime "%Y", @lt;
        $url = $NSE_URL . "/content/historical/EQUITIES/$year/$month/cm$day$month${year}bhav.csv.zip";
        $req = HTTP::Request->new(GET => $url);     #added for fileless
        $reply = $ua->request($req);
        # print "$url", $reply->is_success, $reply->status_line, "\n"; #DEBUG
        if ($reply->is_success or $reply->code == 304) {
            last;
        }
    }

    if (!$reply->is_success  and  $reply->code != 304) {
        $errormsg = "HTTP failure : " . $reply->status_line;
    }

    if (!$errormsg) {
 		#Does not use temp files. Fileless into variable $output
        if (! unzip \$reply->content => \$output) {
            $errormsg = "Unzip error : $UnzipError";
        } else {
			@array = split("\n", $output);
		}
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

    # SYMBOL,SERIES,OPEN,HIGH,LOW,CLOSE,LAST,PREVCLOSE,TOTTRDQTY,TOTTRDVAL,TIMESTAMP,TOTALTRADES,ISIN,
    $csvhead = $array[0];

    @headhash = split /\s*,s*/, $csvhead;
    foreach (@array) {
		my @data = split /\s*,s*/;
		my %datahash;
		my $symbol;
		@datahash{@headhash} = @data;
		if (exists $symbolhash{$datahash{"SYMBOL"}}) {
			$symbol = $datahash{"SYMBOL"};
		}
		elsif(exists $symbolhash{$datahash{"ISIN"}}) {
			$symbol = $datahash{"ISIN"};
		}
		else {
			next;
		}
		$info{$symbol, 'symbol'} = $symbol;
		$info{$symbol, 'close'} = $datahash{"CLOSE"};
		$info{$symbol, 'last'} = $datahash{"LAST"};
		$info{$symbol, 'high'} = $datahash{"HIGH"};
		$info{$symbol, 'low'} = $datahash{"LOW"};
		$info{$symbol, 'open'} = $datahash{"OPEN"};
		$info{$symbol, 'prevclose'} = $datahash{"PREVCLOSE"};
		$quoter->store_date(\%info, $symbol, {eurodate => $datahash{"TIMESTAMP"}});
		$info{$symbol, 'method'} = 'nseindia';
		$info{$symbol, 'currency'} = 'INR';
		$info{$symbol, 'exchange'} = 'NSE';
		$info{$symbol, 'success'} = 1;
    }

    foreach my $symbol (@symbols) {
        unless (exists $info{$symbol, 'success'}) {
			$info{$symbol, 'success'} = 0;
			$info{$symbol, 'errormsg'} = 'Stock not found on NSE.';
		}
    }

    return wantarray ? %info : \%info;
}


1;


=head1 NAME

Finance::Quote::NSEIndia - Obtain quotes from NSE India.

=head1 SYNOPSIS

  use Finance::Quote;

  $q = Finance::Quote->new();

  %info = $q->fetch('nseindia', 'TCS'); # Only query NSE.
  %info = $q->fetch('india', 'TCS'); # Failover to other sources OK.

=head1 DESCRIPTION

This module obtains information about shares listed on the National Stock Exchange of India Ltd.
Source is the daily bhav copy (zipped CSV).

This module provides both the "nseindia" and "india" fetch methods. Please use the "india" fetch method if you wish to have failover with other sources for Indian stocks (such as BSE).

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::NSEIndia:
close, last, high, low, open, prevclose, exchange

=head1 SEE ALSO

National Stock Exchange of India Ltd., http://www.nseindia.com/

=cut
