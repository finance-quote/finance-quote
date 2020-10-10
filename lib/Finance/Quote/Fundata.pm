#!/usr/bin/perl -w
#    The code has been modified by AbstractMethod to
#    retrieve stock information from Fundata 
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


package Finance::Quote::Fundata;
require 5.005;

use strict;

use LWP::UserAgent;
use HTTP::Request::Common;
use HTTP::Request::Common;
use HTML::TokeParser::Simple;

# VERSION

my $DEBUG = 0;

my $FUNDATA_MAINURL = "http://www.fundata.com";
my $FUNDATA_URL = "http://idata.fundata.com/MutualFunds/FundSnapshot.aspx?IID=";

our @totalqueries=();
my $maxQueries = { quantity => 3, seconds => 10};   # allow 'quantity' calls in 'seconds', then sleep


sub methods {
    return (canadamutual => \&fundata,
            fundata => \&fundata);
}

sub labels {
    my @labels = qw/method source name symbol currency date isodate nav/;
    return (canadamutual => \@labels,
            fundata => \@labels);
}

sub sleep_before_query {
    # wait till we can query again
    my $q = $maxQueries->{quantity}-1;
    if ( $#totalqueries >= $q ) {
        my $time_since_x_queries = time()-$totalqueries[$q];
        print STDERR "LAST QUERY $time_since_x_queries\n" if $DEBUG;
        if ($time_since_x_queries < $maxQueries->{seconds}) {
            my $sleeptime = ($maxQueries->{seconds} - $time_since_x_queries) ;
            print STDERR "SLEEP $sleeptime\n" if $DEBUG;
            sleep( $sleeptime );
            print STDERR "CONTINUE\n" if $DEBUG;
        }
    }
    unshift @totalqueries, time();
    pop @totalqueries while $#totalqueries>$q; # remove unnecessary data
    # print STDERR join(",",@totalqueries)."\n";
}


sub fundata {
    my $quoter = shift;
    my @symbols = @_;
    my %info;

    return unless @symbols;

    my $ua = $quoter->user_agent;

    foreach my $symbol (@symbols) {
        my ($day_high, $day_low, $year_high, $year_low);

        $info{$symbol, "success"} = 0;
        $info{$symbol, "symbol"} = $symbol;
        $info{$symbol, "method"} = "fundata";
        $info{$symbol, "source"} = $FUNDATA_MAINURL;
        $info{$symbol, "timezone"} = "EST";

        # Pull the data from the web site
        my $url = $FUNDATA_URL.$symbol;
        print $url."\n"  if ($DEBUG);

        my $reply = $ua->request(GET $url);
        my $code = $reply->code;
        my $desc = HTTP::Status::status_message($code);
        my $body = $reply->content;

        if (!$reply->is_success) {
            $info{$symbol, "errormsg"} = "Error contacting URL";
            next;
        }

        my $parser = HTML::TokeParser::Simple->new(string => $reply->content);

        my $nav = 0;

        while (my $h1 = $parser->get_tag('h1')) {
            my $class = $h1->get_attr('class');
            #print $class if $DEBUG;

            if ($class eq "SnapshotHeader") {
                my $name = $parser->get_trimmed_text('/h1');
                print $name if $DEBUG;
                $info{$symbol, "name"} = $name;
            }
        }

        $parser = HTML::TokeParser::Simple->new(string => $reply->content);

        while (my $span = $parser->get_tag('span')) {
            my $class = $span->get_attr('class');
            my $id = $span->get_attr('id');

            #print $span if ($DEBUG);
            #print $class if ($DEBUG);
            #print $id if ($DEBUG);
           
            if (defined $id and $id eq "ctl00_MainContent_lblNavpsDate") {
                my $rawline = $parser->get_trimmed_text('/span');
                print $rawline."\n" if ($DEBUG);
                # (9/3/2020)
                if ($rawline =~ m/(\d+)\/(\d+)\/(\d\d\d\d)/) {
                    my $month = $1;
                    my $day = $2;
                    my $year = $3;
                    print $month." ".$day." ".$year if ($DEBUG);
                    $quoter->store_date(\%info, $symbol, {month=>$month, day=>$day, year=>$year});
                }
            }

            if (defined $id and $id eq "ctl00_MainContent_txtNavps") {
                $nav = $parser->get_trimmed_text('/span');
                $nav =~ s/\$//g;
                print $nav if ($DEBUG);
                $info{$symbol, "nav"} = $nav;
                $info{$symbol, "success"} = 1;
            }

            print "\n" if ($DEBUG);
        }

        if ($nav == 0) {
            $info{$symbol, "success"} = 0;
            $info{$symbol, "errormsg"} = "Cannot parse quote data";
            next;
        }

        $info{$symbol, "success"} = 1;
        $info{$symbol, "currency"} = "CAD";

        sleep_before_query();
    }

    return wantarray() ? %info : \%info;
}

1;


__END__

=head1 NAME

Finance::Quote::Fundata - Obtain Canadian mutual fund quotes from Fundata

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("fundata","234263");

=head1 DESCRIPTION

This module fetches mutual fund information from Fundata.

Mutual fund symbols on the site are specified numerically.  The best
way to determine the correct symbol is to navigate to the site,
search for the relevant mutual fund, and note the "IID=#####"
which appears in the URL.

In order to not tax the provider with too many requests, by
default the module limits requests to 3 every 10 seconds.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::Fundata :
symbol, name, method, source, timezone, isodate, nav, currency

=head1 SEE ALSO

=cut

