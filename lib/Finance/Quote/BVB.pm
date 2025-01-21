#!/usr/bin/perl -w
# vi: set ts=2 sw=2 noai ic showmode showmatch:  
#
#    Copyright (C) 2023, Bruce Schuck <bschuck@asgard-systems.com>
#
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
#
#    Written as a replacement for Tradeville.pm.

package Finance::Quote::BVB;

use strict;
use warnings;

use POSIX qw(strftime);

use LWP::UserAgent;
use LWP::Simple;
use HTTP::Status;
use IO::String;
use HTTP::Request::Common;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments', '###';

# VERSION

use vars qw($BVB_URL);
$BVB_URL = "https://bvb.ro/TradingAndStatistics/Trading/HistoricalTradingInfo.ashx?day=";

sub methods {
	return (bvb        => \&bvb,
			romania    => \&bvb,
			tradeville => \&bvb,
			europe     => \&bvb);
}

sub labels { 
	my @labels = qw/symbol name market trades volume value open low high avg close refprice var date/;
	
	return (bvb        => \@labels,
			romania    => \@labels,
			tradeville => \@labels,
			europe     => \@labels); 
}

sub bvb {
	my $quoter = shift;
	my @symbols = @_;
	return unless @symbols;

	my (%info, $errormsg, $ua, $req, $date, $reply);
	my @array;
	my $meuradate;

	$ua = $quoter->user_agent;
	# Set the ua to be blank. Server blocks default useragent.
	$ua->agent('');

	# Try to fetch last 10 days historical data file
    for (my ($days, $now) = (0, time()); $days < 10; $days++) {
        # Ex: https://bvb.ro/TradingAndStatistics/Trading/HistoricalTradingInfo.ashx?day=20240809
        my @lt = localtime($now - $days*24*60*60);
        
        my ($url, $output);	# added $req, $output for fileless
        
        $date = strftime "%Y%m%d", @lt;
		$url = sprintf("https://bvb.ro/TradingAndStatistics/Trading/HistoricalTradingInfo.ashx?day=%s", $date);
        $req = get($url);     #added for fileless
        die "Couldn't get data!" unless defined $req;
        
        if ($req ne "") {
			last;
		}
    }

	#Set the date to the date of the last available historical file date
	$meuradate = $date;
	
	#Remove quotation marks around every field in the file.
	$req =~ s/"//g;
	#If the file is empty, die with error
	if ($req eq "") {
		die "Can't GET data";
	}
	
	@array = split("\n", $req);

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

	# "Symbol","Name","Market","Trades","Volume","Value","Open","Low","High","Avg.","Close","Ref. price","Var (%)"
    
    $csvhead = $array[0];

    @headhash = split(/\s*,s*/, $csvhead);

	
    foreach (@array) {
		my @data = split(",", $_);
		my %datahash;
		my $symbol;
		@datahash{@headhash} = @data;
    
		if (exists $symbolhash{$datahash{"Symbol"}}) {
			$symbol = $datahash{"Symbol"};
		}
		else {
			next;
		}
    
		$info{$symbol, 'symbol'} = $symbol;
		$info{$symbol, 'close'} = $datahash{"Close"};
		$info{$symbol, 'last'} = $datahash{"Close"};
		$info{$symbol, 'high'} = $datahash{"High"};
		$info{$symbol, 'low'} = $datahash{"Low"};
		$info{$symbol, 'open'} = $datahash{"Open"};
		$info{$symbol, 'name'} = $datahash{"Name"};
		$quoter->store_date(\%info, $symbol, {isodate => $meuradate});
		$info{$symbol, 'method'} = 'bvb';
		$info{$symbol, 'currency'} = 'RON';
		$info{$symbol, 'exchange'} = 'BVB';
		$info{$symbol, 'success'} = 1;
    }

    foreach my $symbol (@symbols) {
        unless (exists $info{$symbol, 'success'}) {
			### Not Found: $symbol
			$info{$symbol, 'success'} = 0;
			$info{$symbol, 'errormsg'} = 'Stock not found on BVB.';
		}
    }
 
	return wantarray() ? %info : \%info;
	return \%info;

}

1;

__END__

=head1 NAME

Finance::Quote::BVB - Obtain quotes from Bucharest Stock Exchange.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = $q->fetch("bvb", "tlv");  # Only query bvb

    %info = $q->fetch("romania", "brd");     # Failover to other sources OK.

=head1 DESCRIPTION

This module fetches information from L<https://bvb.ro/>.

This module is loaded by default on a Finance::Quote object. It's also possible
to load it explicitly by placing "bvb" in the argument list to
Finance::Quote->new().

This module provides "bvb", "tradeville", "romania", and "europe"
fetch methods. It was written use historical trade data file posted by BVB
on their site.

Information obtained by this module may be covered by Bucharest Stock
Exchange terms and conditions.

=head1 LABELS RETURNED

The following labels are returned: 

=over

=item *

name

=item *

symbol

=item *

open

=item *

high

=item *

low

=item *

price

=item *

bid

=item *

ask

=item *

date

=item *

currency (always RON)

=back
