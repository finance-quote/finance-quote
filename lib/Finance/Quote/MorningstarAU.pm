#!/usr/bin/perl -w
#
#    Copyright (C) 2019, Jalon Avens
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
#    Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
#    02111-1307, USA
#
package Finance::Quote::MorningstarAU;
require 5.005;

use strict;
use warnings;
# use Data::Dumper;
use HTML::TreeBuilder;
use JSON::Parse;
use HTTP::Request::Common;
use String::Util qw(trim);
use Scalar::Util qw(looks_like_number);

use vars qw($MORNINGSTAR_AU_FUNDS_URL $MORNINGSTAR_AU_LOOKUP_URL);

# VERSION

$MORNINGSTAR_AU_LOOKUP_URL = 'https://www.morningstar.com.au/Ausearch/SecurityCodeAutoLookup?rows=2&fq=SecurityTypeId:(1)&q=';
$MORNINGSTAR_AU_FUNDS_URL = 'https://www.morningstar.com.au/Funds/FundReport/';

sub methods {
    return (aufunds => \&morningstarau, morningstarau => \&morningstarau,);
}

sub labels {
    my @labels = qw/currency date isodate method name price source symbol/;
    return (aufund => \@labels, morningstarau => \@labels);
}

sub look_at_or_after {
    my $node = shift;
    my $condition = shift;
    for (; $node; $node = $node->right())
    {
        return $node if ($condition->($node));
    }
    return $node;
}

sub morningstarau {
    my $quoter = shift;
    my @symbols = @_;

    return unless @symbols;

    my %fund_quotes;

    foreach my $symbol (@symbols) {
        my $symbol_errror_message = process_symbol($quoter, $symbol, \%fund_quotes);
        $fund_quotes{$symbol, 'success'} = ($symbol_errror_message eq '' ? 1 : 0);
        $fund_quotes{$symbol, 'errormsg'} = $symbol_errror_message;
        $fund_quotes{$symbol, 'symbol'} = $symbol;
        $fund_quotes{$symbol, 'method'} = 'morningstarau';
        $fund_quotes{$symbol, 'source'} = 'Finance::Quote::MorningstarAU';
    }

    #say "morningstarau: return: ${\(Dumper(\%fund_quotes))}";

	return wantarray ? %fund_quotes : \%fund_quotes;
}

sub process_symbol {
    my $quoter = shift;
    my $symbol = shift;
    my $fund_quotes = shift;

    my $ua = $quoter->user_agent;

    # Get fund lookup page by APIR code to determine MS code
    my $lookup_url = $MORNINGSTAR_AU_LOOKUP_URL . $symbol;
    my $lookup_reply = $ua->request(GET $lookup_url);
    return "Fund lookup page not found" unless ($lookup_reply->is_success);

    my $lookup_reply_json =  eval {JSON::Parse::parse_json($lookup_reply->decoded_content)};
    return "Lookup page JSON response not be parsed" unless (defined($lookup_reply_json));
    # print "Fund lookup result: " . Dumper($lookup_reply_json);

    my $lookup_result_count = eval {$lookup_reply_json->{'response'}{'numFound'}};
    return "Fund lookup result count missing" unless (looks_like_number($lookup_result_count));
    return "Fund lookup results have more than 1 fund" unless ($lookup_result_count <= 1);
    return "Fund lookup results empty" unless ($lookup_result_count != 0);
    my $symbol_details = eval {$lookup_reply_json->{'response'}{'docs'}[0]};
    return "Lookup details missing" unless (ref $symbol_details eq 'HASH');
    return "Symbol is not a fund" unless ($symbol_details->{'Type'} eq 'FUND');

    # Get ms_code
    my $ms_code = $symbol_details->{'Symbol'};
    return "MS code not found" unless (looks_like_number($ms_code));

    # Get fund_name
    my $fund_name = $symbol_details->{'Name'};
    return "Fund name missing" unless ($fund_name ne "");
    $fund_quotes->{$symbol, 'name'} = $fund_name;

    # Get fund details web page by ms_code
    my $fund_details_url = $MORNINGSTAR_AU_FUNDS_URL . $ms_code;
    my $fund_details_reply = $ua->request(GET $fund_details_url);
    return "Fund page not found" unless ($fund_details_reply->is_success);
    my $root = HTML::TreeBuilder->new_from_content($fund_details_reply->decoded_content);
    my $body = eval { $root->find('body') };
    return "Fund details page body not found" unless (defined($body));

    # Fund Details header
    my $fund_details_header =  eval {
            $body->look_down(
                '_tag', "h3", sub {$_[0]->as_text() eq 'Fund Details'}
            )
        };
    return "Fund Details header not found" unless (defined($fund_details_header));

    # Get Fund Details table
    my $fund_details_table =
        look_at_or_after(
            scalar($fund_details_header->right()),
            sub {$_[0]->find("table") }
        );
    return "Fund Details table not found" unless (defined($fund_details_table));
    #say "Found Fund Details table: ${\($fund_details_table->as_HTML())}";

    # Get currency
    my $currency = eval {
            trim(
                $fund_details_table->look_down(
                    '_tag', 'tr',
                    sub {
                        $_[0]->content_array_ref->[0]->as_text eq 'Base Currency'
                    }
                )->content_array_ref->[1]->as_text()
            )
        };
    return "Currency not found" unless ($currency ne '');
    if ($currency eq '$A') {$currency = "AUD"};
    $fund_quotes->{$symbol, 'currency'} = "AUD";

    # Quick Stats header
    my $quick_stats_header =  eval {
            $body->look_down(
                '_tag', "h3", sub {$_[0]->as_text() eq 'Quick Stats'}
            )
        };
    return "Quick Stats header not found" unless (defined($quick_stats_header));

    # Get date on next line
    my $date_text = $quick_stats_header->right();
    if (defined($date_text) && $date_text->as_text() =~ m[as at (\d{1,}) ([[:alpha:]]{3})[[:alpha:]]* (\d{4})])
    {
        my $day = $1;
        my $month = $2;
        my $year = $3;
        $quoter->store_date($fund_quotes, $symbol, {day => $day, month=>$month, year=>$year});
    } else {
        $quoter->store_date($fund_quotes, $symbol, {today => 1});
    }

    # Get Quick Stats table which is after the date
    my $quick_stats_table =
        look_at_or_after(
            scalar($date_text->right()),
            sub {$_[0]->find("table") }
        );
    return "Quick Stats table not found" unless (defined($quick_stats_table));
    #say "Found Quick Stats table: ${\($quick_stats_table->as_HTML())}";

    # Get price
    my $price = eval {
            $quick_stats_table->look_down(
                '_tag', 'tr',
                sub {
                    $_[0]->content_array_ref->[0]->as_text eq 'Exit Price $'
                }
            )->content_array_ref->[1]->as_text()
        };
    return "Price not found" unless (looks_like_number($price));
    $fund_quotes->{$symbol, 'price'} = $price;

    # Get APIR code and confirm matches $symbol
    my $apir_code = eval {
            $quick_stats_table->look_down(
                '_tag', 'tr',
                sub {
                    $_[0]->content_array_ref->[0]->as_text eq 'APIR Code'
                }
            )->content_array_ref->[1]->as_text()
        };
    return "APIR code not found" unless (defined($apir_code));
    return "APIR code does not match $symbol" unless ($apir_code eq $symbol);

    return '';
}

1;

=head1 NAME

Finance::Quote::MorningstarAU - Obtain Australian managed fund quotes from morningstar.com.au.

=head1 SYNOPSIS

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("morningstarau","<APIR> ...");  # Only query morningstar.com.au using APIRs
    %info = Finance::Quote->fetch("aufunds","<APIR> ...");  # Failover to other sources

=head1 DESCRIPTION

This module fetches information from the MorningStar Funds service
https://morningstar.com.au/ to provide quotes on Australian managed funds in AUD.

Funds are identified by their APIR code.

This module is loaded by default on a Finance::Quote object. It's
also possible to load it explicity by placing "morningstarau" in the argument
list to Finance::Quote->new().

=head2 Managed Funds

This module provides both the "morningstarau" and "aufunds" fetch methods for
fetching Australian funds prices from morningstar.com.au. Please use the
"aufunds" fetch method if you wish to have failover with future sources for
of Ausralian fund quotations which might be provided by other
Finance::Quote modules. Using the "morningstarau" method will guarantee that
your information only comes from the morningstar.com.au website.

=head1 LABELS RETURNED

The following labels may be returned by
Finance::Quote::MorningstarAU::morningstarau:

    name, currency, date, price, source, method, iso_date, success, errormsg.

=head1 SEE ALSO

Morningstart Australia website https://morningstar.com.au

=head1 AUTHOR

Jalon Avens

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2019 by Jalon Avens

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or (at
your option) any later version.

=cut
