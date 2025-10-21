#!/usr/bin/perl -w
#
# vi: set ts=4 sw=4 ic noai expandtab showmode showmatch: 
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@cpan.org>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#    Copyright (C) 2000, Volker Stuerzl <volker.stuerzl@gmx.de>
#    Copyright (C) 2002, Rainer Dorsch <rainer.dorsch@informatik.uni-stuttgart.de>
#    Copyright (C) 2022, Andre Joost <andrejoost@gmx.de>
#    Copyright (C) 2025, Bruce Schuck <bschuck@asgard-systems.com>
#
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
#
# This code derived from Padzensky's work on package Finance::YahooQuote,
# but extends its capabilites to encompas a greater number of data sources.
#
# This code was developed as part of GnuCash <http://www.gnucash.org/>
#
#    Changes:
#    Rewritten for issue #516: 2025-10-21, Bruce Schuck
#      Parses JSON retrieved from
#      https://internal.api.union-investment.de/beta/web/funddata/fundsearch?segment=web_de&type=fondssuche&api-version=beta-2.0.0
#      See module for required API Key

package Finance::Quote::Union;

use strict;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments', '###';

use JSON qw(decode_json);

# VERSION

# This url retrieve a JSON data structure containing data for all funds
our $UNION_URL = 'https://internal.api.union-investment.de/beta/web/funddata/fundsearch?segment=web_de&type=fondssuche&api-version=beta-2.0.0';

our $DISPLAY    = 'Union - German Funds';
our @LABELS     = qw/exchange name date isodate price method currency/;
our $METHODHASH = {subroutine => \&unionfunds, 
                   display => $DISPLAY, 
                   labels => \@LABELS};

sub methodinfo {
    return ( 
        unionfunds => $METHODHASH,
    );
}

sub labels {
    my %m = methodinfo();
    return map {$_ => [@{$m{$_}{labels}}] } keys %m;
}

sub methods {
    my %m = methodinfo();
    return map {$_ => $m{$_}{subroutine} } keys %m;
}

# =======================================================================
# The unionfunds routine gets quotes of UNION funds (Union Invest)
# The URL returns a JSON data structure containing a table containing
# quote data for all funds
#
# This subroutine was written by Bruce Schuck <bschuck@asgard-systems.com>

sub unionfunds
{
    my $quoter = shift;
    my @funds = @_;
    return unless @funds;
    my $ua = $quoter->user_agent;
    my (%info, $json, $results);

    # Set headers. API key is sent as a header.
    my @ua_headers = (
        'Accept'     => 'application/json',
        'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.0.0 Safari/537.36',
        'x-api-key'  => '6d5b7ad050e948ce99516c20fbe37425',
    );    

    # Website not supplying intermediate certificate causing
    # GET to fail
    # The website installed a new certificate. The following line
    # is no longer required.
    # $ua->ssl_opts(verify_hostname => 0, SSL_verify_mode => 0x00);

    # Get JSON data
    my $response = $ua->get($UNION_URL, @ua_headers);
    ### [<now>] Response Code: $response->code

    unless ($response->is_success) {
        foreach my $fund (@funds) {
            $info{$fund, "success"}  = 0;
            $info{$fund, "errormsg"} = "Error accessing $UNION_URL";
        }
        return wantarray() ? %info : \%info;
    }

    # The body should be JSON
    eval {$json = decode_json($response->content)};
    if($@) {
        foreach my $fund (@funds) {
            $info{$fund, "success"}  = 0;
            $info{$fund, "errormsg"} = "No JSON data returned";
        }
        return wantarray() ? %info : \%info;
    }
    # ### [<now>] JSON: $json

    my $componentarray = $json->{'content'}{'container'}{'component'};
    ### Component Array: $componentarray

    unless ($componentarray) {
        foreach my $fund (@funds) {
            $info{$fund, "success"}  = 0;
            $info{$fund, "errormsg"} = "Unexpected JSON data";
        }
        return wantarray() ? %info : \%info;
    }

    # Loop through componentarray looking for result array
    foreach my $component( @$componentarray ) {
        if ( $component->{'result'} ) {
            $results = $component->{'result'};
            last;
        }
    }

    unless ( $results ) {
        foreach my $fund (@funds) {
            $info{$fund, "success"}  = 0;
            $info{$fund, "errormsg"} = "JSON data does not include results";
        }
        return wantarray() ? %info : \%info;
    }

    foreach my $fund (@funds) {
        foreach my $funddata (@$results) {
            if ($fund eq $funddata->{'tableRows'}[0]{'isin'}{'value'} ) {
                $info{$fund, 'success'} = 1;
                $info{$fund, 'name' } = $funddata->{'tableRows'}[0]{'fundName'}{'value'};
                $info{$fund, 'exchange'} = 'UNION';
                $info{$fund, 'symbol'} = $fund;
                $info{$fund, 'price'} = $funddata->{'tableRows'}[0]{'returnPrice'}{'valueSortable'};
                $info{$fund, 'last'} = $funddata->{'tableRows'}[0]{'returnPrice'}{'valueSortable'};
                my $date = $funddata->{'tableRows'}[0]{'date'}{'value'};
                my ($price, $currency) = split(/ /, $funddata->{'tableRows'}[0]{'returnPrice'}{'value'});
                $info{$fund, 'currency'} = $currency;
                $quoter->store_date(\%info, $fund, {eurodate => $date});
                last;
            }
        }
        unless ($info{$fund, 'success'}) {
            $info{$fund, 'success'} = 0;
            $info{$fund, 'errormsg'} = 'Symbol not found';
        }
    }

    return wantarray() ? %info : \%info;

}

1;

__END__

=head1 NAME

Finance::Quote::Union	- Obtain quotes from UNION (Union Investment).

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %stockinfo = $q->fetch("unionfunds","DE0008491002");

=head1 DESCRIPTION

This module obtains information about UNION managed funds.

Information returned by this module is governed by UNION's terms
and conditions.

Note that previous versions of the module required the WKN,
now the ISIN is needed as symbol value.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::UNION:

=over

=item exchange 

=item name 

=item date 

=item price 

=item last

=back

=head1 SEE ALSO

UNION (Union Investment), https://www.union-investment.de/

=cut
