#!/usr/bin/perl -w
#
# FinanceCanada.pm
#
# Version 0.1 Initial version


package Finance::Quote::FinanceCanada;
require 5.004;

use strict;

use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;

my $FINANCECANADA_MAINURL = ("http://finance.canada.com/");
my $FINANCECANADA_URL = ($FINANCECANADA_MAINURL."bin/quote?Symbol=");

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
        my $url = $FINANCECANADA_URL.$symbol;
        #print $url;
        my $response = $ua->request(GET $url);
        #print $response->content;
       
        if (!$response->is_success) {
            $info{$symbol, "success"} = 0;
            $info{$symbol, "errormsg"} = "Error contacting URL";
            next;
        }

        my @headers = [qw(Company Symbol Latest Last)];
        my $te = new HTML::TableExtract(headers => @headers);

        $te->parse($response->content);

        foreach my $ts ($te->table_states) {
            foreach my $row ($ts->rows) {
                chop $row->[1];

		if ($row->[0] eq "Invalid Symbol") {
                    $info{$symbol, "symbol"} = $symbol;
                    $info{$symbol, "success"} = 0;
		} elsif ($row->[1] eq $symbol) {
                    $info{$symbol, "method"} = "financecanada";
                    $info{$symbol, "name"} = $row->[0];
                    $info{$symbol, "symbol"} = $symbol;
                    $info{$symbol, "currency"} = "CAD";
                    $info{$symbol, "source"} = $FINANCECANADA_MAINURL;
                    $info{$symbol, "price"} = $row->[2];
                    $info{$symbol, "nav"} = $row->[2];
                    $info{$symbol, "last"} = $row->[2];

                    if ($row->[3] =~ /(\d{1,2})\/(\d{1,2})/) {
                        # returned date is month/day only if a date is given
                        $quoter->store_date(\%info, $symbol, {month => $1, day => $2});
                    }
                    elsif ($row->[3] =~ /\d+:\d+/) {
                        # default to today if returned time data
                        $quoter->store_date(\%info, $symbol, {today => ""}); 
                    }

                    $info{$symbol, "success"} = 1;
                }

                #print $row->[0]."\n";
                #print $row->[1]."\n";
                #print $row->[2]."\n";
                #print $row->[3]."\n";

            }
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

