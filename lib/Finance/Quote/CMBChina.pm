#!/usr/bin/perl -w
# vi: set ts=2 sw=2 noai ic showmode showmatch:  
#
#    Copyright (C) 2025, Garfield Chen <fatcat1985@outlook.com>
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

#    Changes:
#    Initial Version: 2025-06-06, Garfield Chen

package Finance::Quote::CMBChina;

use strict;
use warnings;
use HTTP::Request::Common;
use Date::Parse;
use Encode qw(decode);
use HTML::TreeBuilder::XPath;

# VERSION

my $CMBCHINA_URL = 'https://cmbchina.com/cfweb/personal/prodvalue.aspx';

our $DISPLAY    = 'CMBChina';
our $FEATURES   = {};
our @LABELS     = qw/symbol nav isodate currency/;
our $METHODHASH = {subroutine => \&cmbchina, 
                   display => $DISPLAY, 
                   labels => \@LABELS,
                   features => $FEATURES};

sub methodinfo {
    return ( 
        cmbchina   => $METHODHASH,
        cmb        => $METHODHASH,
    );
}

sub labels { my %m = methodinfo(); return map {$_ => [@{$m{$_}{labels}}] } keys %m; }

sub methods {
  my %m = methodinfo(); return map {$_ => $m{$_}{subroutine} } keys %m;
}

sub cmbchina {
    my $quoter = shift;
    my @symbols = @_;
    
    my %info;
    my $ua = $quoter->user_agent();
    
    foreach my $symbol (@symbols) {
        my $url = "$CMBCHINA_URL?comCod=000&PrdType=T0052&PrdCode=$symbol";
        my $response = $ua->request(GET $url);
        
        unless ($response->is_success) {
            $info{$symbol, 'success'} = 0;
            $info{$symbol, 'errormsg'} = "HTTP request failed: " . $response->status_line;
            next;
        }
        
        my $html = $response->decoded_content();
        my $tree = HTML::TreeBuilder::XPath->new;
        $tree->parse($html);
        
        my $product_code = $tree->findvalue('//*[@id="cList"]//table//tr[2]/td[1]/text()');
        my $net_value = $tree->findvalue('//*[@id="cList"]//table//tr[2]/td[3]/text()');
        my $date = $tree->findvalue('//*[@id="cList"]//table//tr[2]/td[5]/text()');
        
        $product_code =~ s/^\s+|\s+$//g if defined $product_code;
        $net_value =~ s/^\s+|\s+$//g if defined $net_value;
        $date =~ s/^\s+|\s+$//g if defined $date;
        
        unless ($product_code && $product_code eq $symbol) {
            $info{$symbol, 'success'} = 0;
            $info{$symbol, 'errormsg'} = "Product code mismatch or not found";
            next;
        }
        
        $info{$symbol, 'success'} = 1;
        $info{$symbol, 'symbol'} = $product_code;
        $info{$symbol, 'nav'} = $net_value;
        $info{$symbol, 'method'} = 'cmbchina';
        $info{$symbol, 'currency'} = 'CNY';
        
        if ($date) {
            my $formatted_date = substr($date, 0, 4) . "-" . substr($date, 4, 2) . "-" . substr($date, 6, 2);
            $quoter->store_date(\%info, $symbol, { iso => $formatted_date });
        }
    }
    
    return wantarray() ? %info : \%info;
}

1;

__END__

=head1 NAME

Finance::Quote::CMBChina - Obtain fund values from China Merchants Bank

=encoding utf8

=head1 SYNOPSIS

    use Finance::Quote;
    
    $q = Finance::Quote->new('CMBChina');
    %info = $q->fetch('cmbchina', 'XY040208');

=head1 DESCRIPTION

This module fetches fund values from China Merchants Bank's website
(https://cmbchina.com/cfweb/personal/prodvalue.aspx?comCod=000&PrdType=T0057&PrdCode=). It specifically targets the product value page
for wealth management products.

=head1 LABELS RETURNED

The following labels are returned:

=over


=item symbol

=item nav

=item isodate

=item currency

=back

=cut