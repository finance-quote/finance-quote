#!/usr/bin/perl -w

#
# Initial version based on IndiaMutual.pm
#

package Finance::Quote::NSEIndia;
require 5.010;

use strict;
use POSIX qw(strftime);
use IO::Uncompress::Unzip qw(unzip $UnzipError);

# VERSION

use vars qw($NSE_MAIN_URL $NSE_URL);
$NSE_MAIN_URL = "https://www.nseindia.com";
$NSE_URL = "https://archives.nseindia.com";

my $cachedir = $ENV{TMPDIR} // $ENV{TEMP} // '/tmp/';
my $NSE_ZIP = $cachedir.'nseindia.zip';
my $NSE_CSV = $cachedir.'nseindia.csv';

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

    $ua = $quoter->user_agent;
    # Disable redirects - server redirects instead of 404.
    $ua->requests_redirectable([]);

    my %mnames = ('01' => 'JAN', '02' => 'FEB', '03' => 'MAR', '04' => 'APR', '05' => 'MAY', '06' => 'JUN',
          '07' => 'JUL', '08' => 'AUG', '09' => 'SEP', '10' => 'OCT', '11' => 'NOV', '12' => 'DEC');
    # Try to fetch last 10 days
    for (my ($days, $now) = (0, time()); $days < 10; $days++) {
        # Ex: https://archives.nseindia.com/content/historical/EQUITIES/2020/APR/cm23APR2020bhav.csv.zip
        my @lt = localtime($now - $days*24*60*60);
        my ($day, $month, $year, $url);
        $day = strftime "%d", @lt;
        $month = $mnames{strftime "%m", @lt}; # Can't use %b as it's locale dependent.
        $year = strftime "%Y", @lt;
        $url = $NSE_URL . "/content/historical/EQUITIES/$year/$month/cm$day$month${year}bhav.csv.zip";
        $reply = $ua->mirror($url, $NSE_ZIP);
        # print "$url", $reply->is_success, $reply->status_line, "\n"; #DEBUG
        if ($reply->is_success or $reply->code == 304) {
            last;
        }
    }

    if (!$reply->is_success  and  $reply->code != 304) {
        $errormsg = "HTTP failure : " . $reply->status_line;
    }

    if (!$errormsg) {
        if (! unzip $NSE_ZIP => $NSE_CSV) {
            $errormsg = "Unzip error : $UnzipError";
        }
    }

    if (!$errormsg) {
        if (! open $fh, '<', $NSE_CSV) {
            $errormsg = "CSV open error: $!";
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
    $csvhead = <$fh>;
    chomp $csvhead;
    @headhash = split /\s*,s*/, $csvhead;
    while (<$fh>) {
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
    close($fh);

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
