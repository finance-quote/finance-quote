#!/usr/bin/perl -w
#    This module is based on a perl script from Wouter van Marle
#    <wouter@squirrel-systems.com> and on the existing
#    Finance::Quote::ASEGR module.
#
#    The two were compined by David Hampton <hampton@employees.org> to
#    be able to retrieve stock information from the American
#    International Assurance website in Hong Kong.
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

require 5.005;

use strict;

package Finance::Quote::AIAHK;

use vars qw($VERSION $AIAHK_URL);

use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;

$VERSION = '1.17';
$AIAHK_URL = 'http://www.aia.com.hk/daily/fund_mst_rightb.asp?cat=BR_AC';


sub methods { return (aiahk => \&aiahk); }
{ 
	my @labels = qw/name code date isodate price bid offer p_change_3m
	    p_change_1y p_change_3y currency method exchange/;

	sub labels { return (aiahk => \@labels); } 
}

sub aiahk {

    my $quoter = shift;
    my @funds = @_;
    my (%info,$reply,$url,$te,$fund);
    my $ua = $quoter->user_agent();

    $url=$AIAHK_URL;
    $reply = $ua->request(GET $url);
    if (!$reply->is_success) {
	print("1\n");
	foreach my $fund (@funds) {
	    print("2\n");
	    $info{$fund, "success"}=0;
	    $info{$fund, "errormsg"}="Error retreiving fund quote page.";
	}
	return wantarray() ? %info : \%info;
    }
    #print($reply->content, "\n");

    # Now parse the data table contained in the result.  This is the
    # inner of two tables.  There are no headers on this table as they
    # are part of the iframe containing this page.
    $te= new HTML::TableExtract(depth => 1);
    $te->parse($reply->content);

    unless ($te->tables) {
	foreach $fund (@funds) {
	    $info {$fund,"success"} = 0;
	    $info {$fund,"errormsg"} = "Error parsing fund table";
	}
	return wantarray() ? %info : \%info;
    }


    # Was there a parse failure?  If so, record an error for each
    # requested find and get out now.
    my @rows;
    unless (@rows = $te->rows) {
	foreach $fund (@funds) {
	    $info {$fund,"success"} = 0;
	    $info {$fund,"errormsg"} = "Parse error";
	}
	return wantarray() ? %info : \%info;
    }


    # Now find the data for the requested funds.  This is an O(n^^2)
    # algorithm; no way around it.
    foreach $fund (@funds) {
	my $found = 0;
	foreach my $row (@rows) {
	    next if $$row[1] ne $fund;

	    my $tmp;
	    $info{$fund, "success"}=1;
	    $info{$fund, "exchange"}="American International Assurance, Hong Kong";
	    $info{$fund, "method"}="aiahk";
	    $info{$fund, "name"}=$$row[0];
	    $info{$fund, "name"} =~ s/^\s*(.*)\s*$/$1/;
	    $info{$fund, "symbol"}=$fund;
	    $quoter->store_date(\%info, $fund, {usdate => $$row[2]});
	    if ($$row[3] =~ /yield/i) {
		($info{$fund, "yield"}) = $$row[3] =~ m/yield = ([0-9.%]+)/i;
	    } else {
		($tmp=$$row[3]) =~ s/\s*//g;
		($info{$fund, "currency"}, $info{$fund, "bid"}) = $tmp =~ m/([A-Z]+)[^0-9]+([0-9.]+)/;
		($tmp=$$row[4]) =~ s/\s*//g;
		($tmp, $info{$fund, "offer"}) = $tmp =~ m/([A-Z]+)[^0-9]+([0-9.]+)/;

		$info{$fund, "price"} =  $info{$fund, "bid"};

		$info{$fund,"currency"}="USD" if $info{$fund,"currency"} eq "US";
		$info{$fund,"currency"}="HKD" if $info{$fund,"currency"} eq "HK";
		$info{$fund,"currency"}="JPY" if $info{$fund,"currency"} eq "YEN";
	    }
	    # $info{$fund, "p_change_3m"}=$$row[5];
	    # $info{$fund, "p_change_1y"}=$$row[6];
	    # $info{$fund, "p_change_3y"}=$$row[7];

	    $found = 1;
	    last;
	}
	$info{$fund, "success"}=$found;
	$info{$fund, "errormsg"}="Fund $fund not found in list " if !$found;

    }
    return wantarray() ? %info : \%info;
}
1;

=head1 NAME

Finance::Quote::AIAHK Obtain quotes from American International Assurance 

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("aiahk","SCH-HKEQ");

=head1 DESCRIPTION

This module fetches information from the American International
Assurance http://www.aia.com.hk. All funds are available.

This module is loaded by default on a Finance::Quote object. It's 
also possible to load it explicity by placing "AIAHK" in the argument
list to Finance::Quote->new().

Information obtained by this module may be covered by www.aia.com.hk 
terms and conditions See http://www.aia.com.hk/ for details.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::AIAHK :

name code date isodate price bid offer p_change_3m p_change_1y
p_change_3y currency method exchange

=head1 SEE ALSO

American International Assurance, http://www.aia.com.hk

=cut
