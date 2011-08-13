#!/usr/bin/perl
#
#    Copyright (C) 2011, MATSUI Shinsuke <poppen.jp@gmail.com>
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

package Finance::Quote::Bloomberg;

use strict;
use warnings;
use 5.006;

use HTTP::Request::Common;
use Web::Scraper;
use DateTime::Format::Natural;

our $VERSION = '0.03';
my $BLOOMBERG_MAINURL = 'http://www.bloomberg.com/';
my $BLOOMBERG_URL     = 'http://www.bloomberg.com/apps/quote?ticker=';

sub methods {
    return (
        bloomberg_stocks_index => \&bloomberg_stocks_index,
        bloomberg_etf          => \&bloomberg_etf,
        bloomberg_fund         => \&bloomberg_fund
    );
}

{
    my @labels
        = qw/date isodate method source name currency price net p_change open high low/;

    sub labels {
        return (
            bloomberg_stocks_index => \@labels,
            bloomberg_etf          => [ @labels, 'nav', 'p_premium' ],
            bloomberg_fund         => [ (@labels)[ 0 .. 8 ] ]
        );
    }
}

sub bloomberg_stocks_index {
    my ( $quoter, @symbols ) = @_;
    return unless @symbols;

    my %indexes
        = build_info( $quoter, $BLOOMBERG_URL, [ \&_scrape_stocks_index ],
        \@symbols );

    return %indexes if wantarray;
    return \%indexes;
}

sub bloomberg_etf {
    my ( $quoter, @symbols ) = @_;
    return unless @symbols;

    my %etfs
        = build_info( $quoter, $BLOOMBERG_URL, [ \&_scrape_etf ], \@symbols );

    return %etfs if wantarray;
    return \%etfs;
}

sub bloomberg_fund {
    my ( $quoter, @symbols ) = @_;
    return unless @symbols;

    my %funds = build_info( $quoter, $BLOOMBERG_URL, [ \&_scrape_fund ],
        \@symbols );

    return %funds if wantarray;
    return \%funds;
}

sub _scrape_stocks_index {
    my ( $content, $symbol ) = @_;
    my $dt_parser = DateTime::Format::Natural->new;

    my %info = ();
    $info{ $symbol, 'method' } = 'bloomberg_stocks_index';
    $info{ $symbol, 'source' } = $BLOOMBERG_MAINURL;

    my $scraper = scraper {
        process '#price_info .price', 'price_info' => 'TEXT';
        process '.date',              'date'       => 'TEXT';
        process '//div[@id="company_info"]/h1',
            'name' => [ 'TEXT', sub { s/\s+\(.*\)//; } ];
        process '#quote_summary .value',
            'values[]' => [ 'TEXT', sub {s/,//g} ];
    };
    my $result = $scraper->scrape($content);

    if ( defined $result->{price_info} ) {
        $info{ $symbol, 'currency' }
            = ( split( /\s+/, $result->{price_info} ) )[2];
    }
    else {
        $info{ $symbol, 'success' }  = 0;
        $info{ $symbol, 'errormsg' } = "Parse currency error";
        return %info;
    }

    unless ( defined $result->{date} ) {
        $info{ $symbol, 'success' }  = 0;
        $info{ $symbol, 'errormsg' } = "Parse date error";
        return %info;
    }
    my $dt = $dt_parser->parse_datetime( $result->{date} )
        if ( defined $result->{date} );
    if ( $dt_parser->success ) {
        $info{ $symbol, 'isodate' } = $dt->date;
        $info{ $symbol, 'date' }    = $dt->mdy('/');
    }
    else {
        $info{ $symbol, 'success' }  = 0;
        $info{ $symbol, 'errormsg' } = $dt_parser->error;
        return %info;
    }

    if ( defined $result->{name} ) {
        $info{ $symbol, 'name' } = $result->{name};
    }
    else {
        $info{ $symbol, 'success' }  = 0;
        $info{ $symbol, 'errormsg' } = "Parse name error";
        return %info;
    }

    if ( @{ $result->{values} } == 5 ) {
        $info{ $symbol, 'price' } = $result->{values}->[0];
        $info{ $symbol, 'open' }  = $result->{values}->[2];
        $info{ $symbol, 'high' }  = $result->{values}->[3];
        $info{ $symbol, 'low' }   = $result->{values}->[4];

        my ( $net, $p_change ) = split /\s+/, $result->{values}->[1];
        $info{ $symbol, 'net' } = $net;
        $info{ $symbol, 'net' } = $net;
        $p_change =~ s/[\(\)%]//g;
        $info{ $symbol, 'p_change' } = $p_change;
    }
    else {
        $info{ $symbol, 'success' }  = 0;
        $info{ $symbol, 'errormsg' } = "Parse values error";
        return %info;
    }

    $info{ $symbol, 'success' } = 1;
    return %info;
}

sub _scrape_etf {
    my ( $content, $symbol ) = @_;

    my %info = ();
    $info{ $symbol, 'method' } = 'bloomberg_etf';
    $info{ $symbol, 'source' } = $BLOOMBERG_MAINURL;

    my $scraper = scraper {
        process(
        'id("company_info")/h1/text()[1]',
        'name' => [ 'TEXT', sub { s/^\s*(.*?)\s*$/$1/; } ]
        ),
        process(
        '//div[@class="price" and text()=~"PRICE:"]/span[@class="amount"]',
        'price' => [ 'TEXT', sub {s/,//g} ],
        ),
        process(
        '//div[@class="price" and text()=~"PRICE:"]/text()[2]',
        'currency' => [ 'TEXT', sub { s/\s//g; } ]
        ),
        process(
        '//td[@class="name" and text()="Change"]/following-sibling::node()[1]',
        'net' => [ 'TEXT', sub { s/,//g; ( split(/\s+/) )[0]; } ]
        ),
        process(
        '//td[@class="name" and text()="Change"]/following-sibling::node()[1]',
        'p_change' => [ 'TEXT', sub { /\((.*)%\)/; $1 } ]
        ),
        process(
        '//td[@class="name" and text()=~"Open"]/following-sibling::node()',
        'open' => [ 'TEXT', sub {s/,//g} ]
        ),
        process(
        '//td[@class="name" and text()=~"High"]/following-sibling::node()',
        'high' => [ 'TEXT', sub {s/,//g} ]
        ),
        process(
        '//td[@class="name" and text()=~"Low"]/following-sibling::node()',
        'low' => [ 'TEXT', sub {s/,//g} ]
        ),
        process(
        '//td[@class="name" and text()=~"Assets"]/following-sibling::node()[1]',
        'date' => [ 'TEXT', sub { /\(on\s+(.*)\)/; $1; } ]
        ),
        process(
        '//td[@class="name" and text()=~"NAV"]/following-sibling::node()[1]',
        'nav' => [ 'TEXT', sub {s/,//g} ]
        ),
        process(
        '//td[@class="name" and text()=~"Premium"]/following-sibling::node()',
        'p_premium' => 'TEXT'
        );
    };
    my $result = $scraper->scrape($content);

    foreach my $label (
        qw/name price currency net p_change open high low nav p_premium/)
    {
        if ( defined $result->{$label} ) {
            $info{ $symbol, $label } = $result->{$label};
        }
        else {
            $info{ $symbol, 'success' }  = 0;
            $info{ $symbol, 'errormsg' } = "Parse " . $label . " error";
            return %info;
        }
    }

    if ( defined $result->{date} ) {
        my ( $mm, $dd, $yy ) = split '/', $result->{date};
        $info{ $symbol, 'date' } = sprintf "%02d/%02d/%04d", $mm, $dd,
            $yy + 2000;
        $info{ $symbol, 'isodate' } = sprintf "%04d-%02d-%02d", $yy + 2000,
            $mm, $dd;
    }
    else {
        $info{ $symbol, 'success' }  = 0;
        $info{ $symbol, 'errormsg' } = "Parse date error";
        return %info;
    }

    $info{ $symbol, 'success' } = 1;
    return %info;
}

sub _scrape_fund {
    my ( $content, $symbol ) = @_;

    my %info = ();
    $info{ $symbol, 'method' } = 'bloomberg_fund';
    $info{ $symbol, 'source' } = $BLOOMBERG_MAINURL;

    my $scraper = scraper {
        process(
        'id("company_info")/h1/text()[1]',
        'name' => [ 'TEXT', sub { s/^\s*(.*?)\s*$/$1/; } ]
        ),
        process(
        '//div[@class="price" and text()=~"NAV:"]/span[@class="amount"]',
        'price' => [ 'TEXT', sub {s/,//g} ],
        ),
        process(
        '//div[@class="price" and text()=~"NAV:"]/text()[2]',
        'currency' => [ 'TEXT', sub { s/\s//g; } ]
        ),
        process(
        '//td[@class="name" and text()="Change"]/following-sibling::node()[1]',
        'net' => [ 'TEXT', sub { s/,//g; ( split(/\s+/) )[0]; } ]
        ),
        process(
        '//td[@class="name" and text()="Change"]/following-sibling::node()[1]',
        'p_change' => [ 'TEXT', sub { /\((.*)%\)/; $1 } ]
        ),
        process(
        '//td[@class="name" and text()=~"Assets"]/following-sibling::node()[1]',
        'date' => [ 'TEXT', sub { /\(on\s+(.*)\)/; $1; } ]
        );
    };
    my $result = $scraper->scrape($content);

    foreach my $label (qw/name price currency net p_change/) {
        if ( defined $result->{$label} ) {
            $info{ $symbol, $label } = $result->{$label};
        }
        else {
            $info{ $symbol, 'success' }  = 0;
            $info{ $symbol, 'errormsg' } = "Parse " . $label . " error";
            return %info;
        }
    }

    if ( defined $result->{date} ) {
        my ( $mm, $dd, $yy ) = split '/', $result->{date};
        $info{ $symbol, 'date' } = sprintf "%02d/%02d/%04d", $mm, $dd,
            $yy + 2000;
        $info{ $symbol, 'isodate' } = sprintf "%04d-%02d-%02d", $yy + 2000,
            $mm, $dd;
    }
    else {
        $info{ $symbol, 'success' }  = 0;
        $info{ $symbol, 'errormsg' } = "Parse date error";
        return %info;
    }

    $info{ $symbol, 'success' } = 1;
    return %info;
}

sub build_info {
    my ( $quoter, $url, $scrapers_ref, $symbols_ref ) = @_;

    my %info = ();
    my $ua   = $quoter->user_agent;

    foreach my $scraper_ref (@$scrapers_ref) {
        foreach my $symbol (@$symbols_ref) {
            my $uri   = URI->new( $url . $symbol );
            my $reply = $ua->request( GET $uri);
            if ( $reply->is_success ) {
                %info = ( %info, $scraper_ref->( $reply->content, $symbol ) );
            }
            else {
                $info{ $symbol, 'success' }  = 0;
                $info{ $symbol, 'errormsg' } = "HTTP failure";
            }
        }
    }

    return %info;
}

1;

=head1 NAME

Finance::Quote::Bloomberg - Obtain quotes from Bloomberg.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    # Fetching Stock Index Information
    %quotes = $q->fetch( 'bloomberg_stocks_index', "stock-index-ticker" );

    # Fetching ETF Information 
    %quotes = $q->fetch( 'bloomberg_etf', "etf-ticker" );

=head1 DESCRIPTION

This module obtains information from Bloomberg. Currently Information of
Stock Index, ETF and Fund can be fetched. Query them with ticker symbols.
To find their tickers, search http://www.bloomberg.com/ or Yahoo! Finance
and so on.

Information returned by this module is governed by Bloomberg's terms and
conditions.

=head1 LABELS RETURNED

=head2 bloomberg_stocks_index()

The following labels may be returned by Finance::Quote::Bloomberg::bloomberg_stocks_index:
date, isodate, method, source, name, currency, price, net, p_change, open, high and low.

=head2 bloomberg_etf()

The following labels may be returned by Finance::Quote::Bloomberg::bloomberg_etf:
date, isodate, method, source, name, currency, price, net, p_change, open, high, low, nav and p_premium.

The p_premium means the ETF's percent premium/discount.

=head2 bloomberg_fund()

The following labels may be returned by Finance::Quote::Bloomberg::bloomberg_fund:
date, isodate, method, source, name, currency, price, net and p_change.

=head1 SEE ALSO

Bloomberg, http://www.bloomberg.com/

=cut
