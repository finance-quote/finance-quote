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
use YAML;

our $VERSION = '0.01';
my $BLOOMBERG_MAINURL          = 'http://www.bloomberg.com/';
my $BLOOMBERG_STOCKS_INDEX_URL = 'http://www.bloomberg.com/apps/quote?ticker=';

sub methods { return ( bloomberg_stocks_index => \&bloomberg_stocks_index ); }

{
    my @labels =
      qw/date isodate method source name currency price net p_change open high low/;
    sub labels { return ( bloomberg_stocks_index => \@labels ); }
}

sub bloomberg_stocks_index {
    my ( $quoter, @symbols ) = @_;
    return unless @symbols;

    my %indexes = ();
    my $ua      = $quoter->user_agent;

    foreach my $symbol (@symbols) {
        my $uri   = URI->new( $BLOOMBERG_STOCKS_INDEX_URL . $symbol );
        my $reply = $ua->request( GET $uri);
        if ( $reply->is_success ) {
            %indexes =
              ( %indexes, _scrape_stocks_index( $reply->content, $symbol ) );
        }
        else {
            $indexes{ $symbol, 'success' }  = 0;
            $indexes{ $symbol, 'errormsg' } = "HTTP failure";
        }
    }

    return %indexes if wantarray;
    return \%indexes;
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
          'values[]' => [ 'TEXT', sub { s/,//g } ];
    };
    my $result = $scraper->scrape($content);

    if ( defined $result->{price_info} ) {
        $info{ $symbol, 'currency' } =
          ( split( /\s+/, $result->{price_info} ) )[2];
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

1;

=head1 NAME

Finance::Quote::Bloomberg - Obtain quotes from Bloomberg.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %quotes = $q->fetch( 'bloomberg_stocks_index', "stock-index-ticker" );

=head1 DESCRIPTION

This module obtains information about World Stock Indexes from Bloomberg.
Query it with ticker symbols.

Information returned by this module is governed by Bloomberg's terms and
conditions.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::Bloomberg:
date, isodate, method, source, name, currency, price, net, p_change,
open, high and low.

=head1 SEE ALSO

Bloomberg, http://www.bloomberg.com/

=cut
