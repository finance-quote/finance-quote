#!/usr/bin/perl -w

#
# Initial version based on NSEIndia.pm
#

package Finance::Quote::BSEIndia;
require 5.010;

use strict;
use POSIX qw(strftime);
use IO::Uncompress::Unzip qw(unzip $UnzipError);

# VERSION

use vars qw($BSE_URL);
$BSE_URL = "https://www.bseindia.com";

my $cachedir = $ENV{TMPDIR} // $ENV{TEMP} // '/tmp/';
my $BSE_ZIP = $cachedir.'bseindia.zip';
my $BSE_CSV = $cachedir.'bseindia.csv';

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

    $ua = $quoter->user_agent;
    # Set the ua to be blank. Server blocks default useragent.
    $ua->agent('');

    # Try to fetch last 10 days
    for (my ($days, $now) = (0, time()); $days < 10; $days++) {
        # Ex: https://www.bseindia.com/download/BhavCopy/Equity/EQ_ISINCODE_150520.zip
        my @lt = localtime($now - $days*24*60*60);
        my ($date, $url);
        $date = strftime "%d%m%y", @lt;
        $url = $BSE_URL . "/download/BhavCopy/Equity/EQ_ISINCODE_${date}.zip";
        $reply = $ua->mirror($url, $BSE_ZIP);
        # print "$url", $reply->is_success, $reply->status_line, "\n"; #DEBUG
        if ($reply->is_success or $reply->code == 304) {
            last;
        }
    }

    if (!$reply->is_success  and  $reply->code != 304) {
        $errormsg = "HTTP failure : " . $reply->status_line;
    }

    if (!$errormsg) {
        if (! unzip $BSE_ZIP => $BSE_CSV) {
            $errormsg = "Unzip error : $UnzipError";
        }
    }

    if (!$errormsg) {
        if (! open $fh, '<', $BSE_CSV) {
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

    # SC_CODE,SC_NAME,SC_GROUP,SC_TYPE,OPEN,HIGH,LOW,CLOSE,LAST,PREVCLOSE,NO_TRADES,NO_OF_SHRS,NET_TURNOV,TDCLOINDI,ISIN_CODE,TRADING_DATE,FILLER2,FILLER3
    $csvhead = <$fh>;
    chomp $csvhead;
    @headhash = split /\s*,s*/, $csvhead;
    while (<$fh>) {
    my @data = split /\s*,s*/;
    my %datahash;
    my $symbol;
    @datahash{@headhash} = @data;
    if (exists $symbolhash{$datahash{"SC_CODE"}}) {
        $symbol = $datahash{"SC_CODE"};
    }
    elsif(exists $symbolhash{$datahash{"ISIN_CODE"}}) {
        $symbol = $datahash{"ISIN_CODE"};
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
    $info{$symbol, 'name'} = $datahash{"SC_NAME"};
    $quoter->store_date(\%info, $symbol, {eurodate => $datahash{"TRADING_DATE"}});
    $info{$symbol, 'method'} = 'bseindia';
    $info{$symbol, 'currency'} = 'INR';
    $info{$symbol, 'exchange'} = 'BSE';
    $info{$symbol, 'success'} = 1;
    }
    close($fh);

    foreach my $symbol (@symbols) {
        unless (exists $info{$symbol, 'success'}) {
        print "$symbol not found\n";
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
