#!/usr/bin/env perl
package Finance::Quote::MorningstarUS;
require 5.014;
use strict;
use warnings;
use JSON qw( decode_json );
use Time::Seconds;
use Time::Piece ();
use LWP::UserAgent;
use HTTP::Request::Common;

sub methods { return (morningstarus => \&morningstarus); }

{
  my @labels = qw/date isodate method source name currency price open close last high low/;

  sub labels { return (morningstarus => \@labels); }
}


sub morningstarus {
	my $quoter  = shift;
	my @symbols = @_;

	return unless @symbols;
	my ($ua, $reply, $url, %funds);

	# search the past 7 days for the most recent close
	my $ttil = Time::Piece->new();
	my $tfrom = $ttil - (ONE_DAY * 7);
	$tfrom = $tfrom->strftime('%Y-%m-%d');
	$ttil = $ttil->strftime('%Y-%m-%d');

	$url = 'http://globalquote.morningstar.com/globalcomponent/RealtimeHistoricalStockData.ashx?ticker=%s&showVol=false&dtype=his&f=d&curry=USD&range=%s|%s&isD=true&isS=true&hasF=true&ProdCode=DIRECT';
	$url = sprintf($url, join(",",@symbols), $tfrom, $ttil);
	$ua    = $quoter->user_agent;
	$reply = $ua->request(GET $url);

	unless ($reply->is_success) {
	  foreach my $symbol (@symbols) {
		$funds{$symbol, "success"}  = 0;
		$funds{$symbol, "errormsg"} = "HTTP failure";
	  }
	  return wantarray ? %funds : \%funds;
	}

	my $jsons = $reply->content;
	$jsons =~ s/":NaN,"/":null,"/; # They aren't quite JSON, so we have to replace NaN's with null
	my $json = decode_json($jsons);

	my @pricedata = @{ $json->{'PriceDataList'} }; # get the PDL as an @array
	my $relative = ( $json->{'PriceType'} eq "return" ); #whether price type is a return or abs value
	my @dates;
	foreach my $info ( @pricedata ) {
		# Morningstar always returns in "Exchange:TICKER" format, so strip off the exchange
		my $name = $info->{"Symbol"};
		$name =~ s/^.*://;

		# Extract the actual prices
		my @datapoints = @{ $info->{'Datapoints'} };
		my @data = @{ $datapoints[$#datapoints] }; # gets the most recent (last) price data segment
		my $closing = $data[0]; # This works if we are only requesting one item ([close, max, min, open] is the format)
		# If we are requesting more than one ticker, the close (but not max, min, or open) is made relative, with the first day being 0 (0% change) always
		if ($relative)
		{
			$closing = sprintf("%.2f", $info->{"StartPos"} * (1 + ($data[0] / 100.0)));
		}

		# Only the first result has the actual date indexes to save space, so we cache it
		if ($info->{'DateIndexs'})
		{
			@dates = @{$info->{'DateIndexs'}};
		}
		# Morningstar uses "days since 1900-01-01" as it's day index
		my $basedate = Time::Piece->strptime('19000101', '%Y%m%d');
		my $numdays = $dates[$#dates];
		$basedate += ONE_DAY * $numdays;
		my $ondate = $basedate->strftime('%Y-%m-%d');

		# Insert all the information gathered from Morningstar
		$quoter->store_date(\%funds, $name, {isodate => $ondate});
		$funds{$name, 'method'}   = 'morningstar_us';
		$funds{$name, 'price'}    = $closing;
		$funds{$name, 'close'}    = $closing;
		$funds{$name, 'last'}    = $closing;
		$funds{$name, 'high'}    = ($data[1] ? $data[1] : $closing);
		$funds{$name, 'low'}    = ($data[2] ? $data[2] : $closing); #[close, max, min, open], except mutual funds only have close
		$funds{$name, 'open'}    =  ($data[3] ? $data[3] : $closing);
		$funds{$name, 'currency'} = "USD";
		$funds{$name, 'success'}  = 1;
		$funds{$name, 'symbol'}  = $name;
		$funds{$name, 'source'}   = 'Finance::Quote::MorningstarUS';
		$funds{$name, 'name'}   = $name;
	}

	# Check for undefined symbols
	foreach my $symbol (@symbols) {
	  unless ($funds{$symbol, 'success'}) {
		$funds{$symbol, "success"}  = 0;
		$funds{$symbol, "errormsg"} = "Fund name not found";
	  }
	}
  return %funds if wantarray;
  return \%funds;
}

1;

=head1 NAME

Finance::Quote::MorningstarUS - Obtain fund & stock prices

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %fundinfo = $q->fetch("morningstarus","fund name");

=head1 DESCRIPTION

This module obtains information about end-of day fund prices from
www.morningstar.com.

=head1 FUND NAMES

Use some smart fund name...

=head1 LABELS RETURNED

Information available from MorningstarUS may include the following labels:
date method source name currency price open close high low. The prices are updated at the
end of each bank day.

=head1 SEE ALSO

Perhaps morningstar?

=cut
