#!/usr/bin/perl -w
#
# FinanceCanada.pm
#
# Version 0.1 Initial version
#
# Version 0.2 Rewrite by David Hampton <hampton@employees.org> for
# changed web site.
#

package Finance::Quote::FinanceCanada;
require 5.004;

use strict;

use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;

my $VERSION = '0.2';
my $FINANCECANADA_MAINURL = ("http://finance.canada.com/");
my $FINANCECANADA_URL = "http://stockgroup.canada.com/sn_overview.asp?symbol=T.";

sub methods {
    return (canada => \&financecanada,
            financecanada => \&financecanada);
}


sub labels {
    my @labels = qw/method source name symbol currency last date isodate nav price/;
    return (canada => \@labels,
            financecanada => \@labels);
}   



sub financecanada {
    my $quoter = shift;
    my @symbols = @_;
    my %info;

    return unless @symbols;

    my $ua = $quoter->user_agent;

    foreach my $symbol (@symbols) {
	my ($day_high, $day_low, $year_high, $year_low);

	$info{$symbol, "success"} = 0;
	$info{$symbol, "symbol"} = $symbol;
	$info{$symbol, "method"} = "financecanada";
	$info{$symbol, "source"} = $FINANCECANADA_MAINURL;

	# Pull the data from the web site
        my $url = $FINANCECANADA_URL.$symbol;
        # print $url;
        my $response = $ua->request(GET $url);
        # print $response->content;
	if (!$response->is_success) {
            $info{$symbol, "errormsg"} = "Error contacting URL";
            next;
        }

	# Parse the page looking for the table containing the full
	# name of the stock
        my $te = new HTML::TableExtract( depth => 2, count => 0);
        $te->parse($response->content);

	# debug
#	foreach my $ts ($te->table_states) {
#	    print "\n***\n*** Table (", join(',', $ts->coords), "):\n***\n";
#	    foreach my $row ($ts->rows) {
#		print join(',', @$row), "\n";
#	    }
#	}

        foreach my $ts ($te->table_states) {
            my $row = $ts->row(0);
	    $info{$symbol, "name"} = $row->[0]
		if ($row->[0] =~ s/^.([\w\s]+).*/$1/);
	}
	if (!defined($info{$symbol, "name"})) {
            $info{$symbol, "errormsg"} = "Invalid symbol";
	    next;
	}

	# Parse the page looking for the table containing the quote
	# details
        $te = new HTML::TableExtract(headers => [qw(Quote)],
				     slice_columns => 0);
        $te->parse($response->content);

	# debug
#	foreach my $ts ($te->table_states) {
#	    print "\n***\n*** Table (", join(',', $ts->coords), "):\n***\n";
#	    foreach my $row ($ts->rows) {
#		print join(',', @$row), "\n";
#	    }
#	}

	# Now parse the quote details.  This method of parsing is
	# independent of which row contains which data item, so if the
	# web site reorders these it won't impact this code.
        foreach my $ts ($te->table_states) {
            foreach my $row ($ts->rows) {

		# Remove leading and trailing white space
		$row->[0] =~ s/^\s*(.+?)\s*$/$1/ if defined($row->[0]);
		$row->[1] =~ s/^\s*(.+?)\s*$/$1/ if defined($row->[1]);

		# Map the row into our data array
		for ($row->[0]) {
		    /^Last Traded/ && do { s/Last Traded: (.*) ../$1/;
					   $quoter->store_date(\%info, $symbol, { usdate => $_}); };
		    /^Last$/	&& do { $info{$symbol, "last"} = $row->[1];
					$info{$symbol, "price"} = $row->[1];
					$info{$symbol, "nav"} = $row->[1];
					last; };
		    /^Open$/	&& do { $info{$symbol, "open"} = $row->[1]; last; };
		    /^Bid$/	&& do { $info{$symbol, "bid"} = $row->[1]; last; };
		    /^Ask$/	&& do { $info{$symbol, "ask"} = $row->[1]; last; };
		    /^% Change/ && do { $info{$symbol, "p_change"} = $row->[1];
					$info{$symbol, "p_change"} =~ s/%//;
					last; };
		    /^Volume/	&& do { $info{$symbol, "volume"} = $row->[1]; last; };
		    /^Close/	&& do { $info{$symbol, "close"} = $row->[1]; last; };

		    /^Day High$/  && do { $info{$symbol, "high"} = $row->[1]; last; };
		    /^Day Low$/	  && do { $info{$symbol, "low"} = $row->[1]; last; };
		    /^Year High$/ && do { $year_high = $row->[1]; last; };
		    /^Year  Low$/ && do { $year_low = $row->[1]; last; };

		    $info{$symbol, "success"} = 1;
		};
	    }
	}

	if ($info{$symbol, "success"} == 1) {
	    $info{$symbol, "currency"} = "CAD";
	    foreach (keys %info) {
		$info{$_} =~ s/\$//;
	    }
	    $info{$symbol, "day_range"} = $info{$symbol, "low"} . " - " . $info{$symbol, "high"}
	    if (defined($info{$symbol, "high"}) && defined($info{$symbol, "low"}));
	    
	    if (defined($year_high) && defined($year_low)) {
		$info{$symbol, "year_range"} = "$year_low - $year_high";
	    }
	} else {
            $info{$symbol, "errormsg"} = "Cannot parse quote data";
	}
    }

    return wantarray() ? %info : \%info;
}

1;

=head1 NAME

Finance::Quote::FinanceCanada - Obtain stock and mutual fund prices from
finance.canada.com

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    # Can failover to other methods
    %quotes = $q->fetch("canada", "stock_fund-code");
    
    # Use this module only
    %quotes = $q->fetch("financecanada", "stock_fund-code");

=head1 DESCRIPTION

This module obtains information about Canadian Stock and Mutual Funds from
finanace.canada.com.  The information source "canada" can be used if the
information source is unimportant, or "financecanada" to specifically use
finance.canada.com.

=head1 STOCK_FUND-CODE

Canadian stocks/mutual funds do not have a unique symbol identifier.  This
module uses the symbols as used on finance.canada.com.  The simplest way
to fetch the ID for a particular stock/fund is to go to finance.canada.com,
search for your particular stock or mutual fund, and note the symbol ID.
This is helpfully provided by the site in their returned HTML quote.

=head1 LABELS RETURNED

Information available from financecanada may include the following labels:

method source name symbol currency date nav last price

=head1 SEE ALSO

Finance Canada.com website - http://finance.canada.com/

Finance::Quote

=cut

