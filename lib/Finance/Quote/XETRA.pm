#!/usr/bin/perl -w
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

package Finance::Quote::XETRA;

use strict;
use warnings;
use HTML::Entities;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use LWP::UserAgent;
use Web::Scraper;

our $VERSION = '1.52'; # VERSION

my $xetra_URL = 'https://web.s-investor.de/app/detail.htm?INST_ID=0000057&boerse=GER&isin=';

sub methods { 
  return (xetra => \&xetra,
          europe     => \&xetra); 
}

our @labels = qw/symbol last close p_change volume open price/;

sub labels { 
  return (xetra => \@labels,
          europe     => \@labels); 
}

sub xetra {
  my $quoter = shift;
  my @stocks = @_;
  my %info;
  my $ua = $quoter->user_agent();
 {
  foreach my $stock (@stocks) {
    eval {
	  my $url = $xetra_URL.join('', $stock);
	  my $symlen = length($stock);
	  
      my $tree = HTML::TreeBuilder->new_from_url($url);
	  	  
	  my $lastvalue = $tree->look_down('class'=>'si_inner_content_box');

	  my $td1 = ($lastvalue->look_down('_tag'=>'td'))[1];
      my @child = $td1->content_list;
	  my $isin =$child[0];
	  
	  $td1 = ($lastvalue->look_down('_tag'=>'td'))[3];	
      @child = $td1->content_list;	
      my $sharename = $child[0];
	  
	  $td1 = ($lastvalue->look_down('_tag'=>'td'))[5];	
      @child = $td1->content_list;
      my $exchange = $child[0];	  
	  
	  $td1 = ($lastvalue->look_down('_tag'=>'td'))[7];	
      @child = $td1->content_list;
      my $date = substr($child[0], 0, 8);
	  
	  $td1 = ($lastvalue->look_down('_tag'=>'td'))[9];	
	  @child = $td1->content_list;
      my $price = $child[0];
      $price =~ s/,/./;
	  my $encprice = encode_entities($price);	  
	  my @splitprice= split ('&',$encprice);	  
      $price = $splitprice[0];
	  
	  $td1 = ($lastvalue->look_down('_tag'=>'td'))[11];	
	  @child = $td1->content_list;
      my $currency = $child[0];
      $currency =~ s/Euro/EUR/;	  

	        
      $info{$stock, 'success'}   = 1;
      $info{$stock, 'method'}    = 'xetra';
      $info{$stock, 'symbol'}    = $isin;
	  $info{$stock, 'name'}      = $sharename;
	  $info{$stock, 'exchange'}  = $exchange;	  
      $info{$stock, 'last'}      = $price;
      $info{$stock, 'price'}     = $price;
      $info{$stock, 'currency'}  = $currency;
#      $info{$stock, 'date'}      = $date;
      $quoter->store_date(\%info, $stock, {eurodate => $date});
    };
    if ($@) {
      $info{$stock, 'success'}  = 0;
      $info{$stock, 'errormsg'} = "Error retreiving $stock: $@";
    }

  return wantarray() ? %info : \%info;
}
}
}
1;

=head1 NAME

Finance::Quote::xetra - Obtain quotes from S-Investor platform.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("xetra", "DE000ENAG999");  # Only query xetra
    %info = Finance::Quote->fetch("europe", "brd");     # Failover to other sources OK.

=head1 DESCRIPTION

This module fetches information from https://s-investor.de/, the investment platform
of the German Sparkasse banking group.

This module is loaded by default on a Finance::Quote object. It's also possible
to load it explicitly by placing "xetra" in the argument list to
Finance::Quote->new().

This module provides "xetra" and "europe" fetch methods.

Information obtained by this module may be covered by s-investor.de terms and
conditions.

=head1 LABELS RETURNED

The following labels are returned: 
currency
exchange
last
method
success
symbol


