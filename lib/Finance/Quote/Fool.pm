#!/usr/bin/perl -w
#    This module was rewritten in June 2019 based on the 
#    Finance::Quote::IEXCloud.pm module and prior versions of Fool.pm
#    that carried the following copyrights:
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@cpan.org>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#    Copyright (C) 2001, Tobias Vancura <tvancura@altavista.net>
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

package Finance::Quote::Fool;

use strict;
use HTTP::Request::Common;
use HTML::TableExtract;
use HTML::TreeBuilder;
use Text::Template;
use Encode qw(decode);

# VERSION

my $URL = Text::Template->new(TYPE => 'STRING', SOURCE => 'http://caps.fool.com/Ticker/{$symbol}.aspx');

sub methods { 
  return ( fool   => \&fool,
           usa    => \&fool,
           nasdaq => \&fool,
           nyse   => \&fool);
}

my @labels = qw/date isodate open high low close volume last/;
sub labels {
  return ( iexcloud => \@labels, );
}

sub fool {
    my $quoter = shift;
    my @stocks = @_;
    
    my (%info, $symbol, $url, $reply, $code, $desc, $body);
    my $ua = $quoter->user_agent();
    
    my $quantity = @stocks;

    foreach my $symbol (@stocks) {
        # Get the web page
        $url   = $URL->fill_in(HASH => {symbol => $symbol});
        $reply = $ua->request( GET $url);
        $code  = $reply->code;
        $desc  = HTTP::Status::status_message($code);
        $body  = decode('UTF-8', $reply->content);
  
        if ($code != 200) {
            $info{ $symbol, 'success' } = 0;
            $info{ $symbol, 'errormsg' } = $desc;
            next;
        }

        # Parse the web page
        my $root      = HTML::TreeBuilder->new_from_content($body);
        my $timestamp = $root->look_down(_tag => 'p', class => 'timestamp')->as_text;
        
        my $te = HTML::TableExtract->new();
        $te->parse($body);
        my $ts = $te->first_table_found();
        my %data;
        
        foreach my $row ($ts->rows) {
          my %slice = @$row;
          %data = (%data, %slice); 
        }
  
        # Assign the results
        eval {
          $info{$symbol, 'symbol'}             = $symbol;
          $info{$symbol, 'method'}             = 'fool';
          $info{$symbol, 'day_range'}          = $data{'Daily Range'} =~ s/[\$,]//g ? $data{'Daily Range'} : die('failed to parse daily range');
          $info{$symbol, 'open'}               = $data{'Open'} =~ s/[\$,]//g ? $data{'Open'} : die('failed to parse open');
          $info{$symbol, 'volume'}             = $data{'Volume'} =~ m/[0-9,]+/ ? $data{'Volume'} =~ s/,//gr : die('failed to parse volume');
          $info{$symbol, 'close'}              = $data{'Prev. Close'} =~ s/[\$,]//g ? $data{'Prev. Close'} : die('failed to parse previous close');
          $info{$symbol, 'year_range'}         = $data{'52-Wk Range'} =~ s/[\$,]//g ? $data{'52-Wk Range'} : die('failed to parse year range');
          $info{$symbol, 'last'}               = $data{'Current Price'} =~ s/[\$,]//g ? $data{'Current Price'} : die('failed to parse last price');
          $info{$symbol, 'currency'}           = 'USD';
          $info{$symbol, 'currency_set_by_fq'} = 1;
          $info{$symbol, 'success'}            = 1;
          
          # 03:38 PM EDT on 06/19/19
          $quoter->store_date( \%info, $symbol, { usdate => $1 } ) if  $timestamp =~ m|([0-9]{2}/[0-9]{2}/[0-9]{2})|;
        }
        or do {
          $info{$symbol, 'errormsg'} = $@;
          $info{$symbol, 'success'}  = 0;
        }
    }

    return wantarray() ? %info : \%info;
}

1;

=head1 NAME

Finance::Quote::Fool - Obtain quotes from the Motley Fool web site.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %stockinfo = $q->fetch("fool","GE", "INTC");

=head1 DESCRIPTION

This module obtains information from the Motley Fool website
(http://caps.fool.com). The site provides date from NASDAQ, NYSE and AMEX.

This module is loaded by default on a Finance::Quote object.  It's
also possible to load it explicitly by placing "Fool" in the argument
list to Finance::Quote->new().

Information returned by this module is governed by the Motley Fool's terms and
conditions.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::Fool:
symbol, day_range, open, volume, close, year_range, last, currency,
method.

=head1 SEE ALSO

Motley Fool, http://caps.fool.com

Finance::Quote.

=cut
