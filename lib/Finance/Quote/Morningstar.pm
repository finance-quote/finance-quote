#!/usr/bin/perl -w

# Module for morningstar.co.uk

use strict;

use Encode;

package Finance::Quote::Morningstar;

my $MORNINGSTAR_BASE_URL = 'http://www.morningstar.co.uk/UK/snapshot/snapshot.aspx?id=';

sub methods
{
	return (morningstar => \&morningstar);
}

sub labels
{
	return (morningstar => ['symbol', 'date', 'isodate', 'nav', 'currency']);
}

sub _scrape($$$$)
{
	my ($quoter, $i, $sym, $html) = @_;

	if (my ($isin, $d, $m, $y, $currency, $nav) =
		$html =~ />ISIN<.*>((?:GB|LU)\d+)<.*>NAV<span class="heading">.*(\d{2})\/(\d{2})\/(\d{4})<[^0-9]*([A-Z]{3}).(\d+\.\d+)</s)
	{
		$i->{$sym, 'success'} = 1;

		$i->{$sym, 'symbol'} = $isin;

		$quoter->store_date($i, $sym,
			{year => $y, month => $m, day => $d});

		$i->{$sym,'currency'} = $currency;
		$i->{$sym, 'nav'} = $nav;
	} else {
 		$i->{$sym, 'success'} = 0;
		$i->{$sym, 'errormsg'} = 'Unable to screen-scrape HTML content';
	}
}

sub morningstar
{
	my $quoter = shift;
	my @stocks = @_;

	my $ua = $quoter->user_agent;

	my %info;

	foreach my $sym (@stocks) {
		my $url = $MORNINGSTAR_BASE_URL . $sym;

		my $resp = $ua->get($url);

		if ($resp->is_success) {
			my $contentType = $resp->headers->header('Content-Type');
			 $contentType =~ s/;.*//;

			 if ($contentType eq 'text/html') {
			 	my $dat = $resp->content;

				$dat = Encode::decode('utf-8', $dat);
				_scrape($quoter, \%info, $sym, $dat);
			 } else {
			 	$info{$sym, 'success'} = 0;
				$info{$sym, 'errormsg'} = 'Unexpected content type: '.$contentType;
			}
		} else {
			$info{$sym, 'success'} = 0;
			$info{$sym, 'errormsg'} = 'Unexpected HTTP response: ' . $resp->status_line;
		}
	}


	if (wantarray) {
		return %info;
	} else {
		return \%info;
	}
}

1;

 	  	 
