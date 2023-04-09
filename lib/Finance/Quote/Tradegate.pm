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

package Finance::Quote::Tradegate;

use strict;
use warnings;
use HTML::Entities;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use LWP::UserAgent;
use Web::Scraper;

# VERSION

my $Tradegate_URL = 'https://web.s-investor.de/app/detail.htm?INST_ID=0000057&boerse=TDG&isin=';

sub methods { 
  return (tradegate => \&tradegate,
          europe     => \&tradegate); 
}

our @labels = qw/symbol last close exchange volume open price/;

sub labels { 
  return (tradegate => \@labels,
          europe     => \@labels); 
}

sub tradegate {
  my $quoter = shift;
  my $ua     = $quoter->user_agent();
  my $agent  = $ua->agent;
  $ua->agent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36');
  
  my %info;
  my $url;
  my $reply;

  foreach my $symbol (@_) {
    eval {
		
	
	  my $url = $Tradegate_URL.join('', $symbol);
	  my $symlen = length($symbol);
	  
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
	  
	  $td1 = ($lastvalue->look_down('_tag'=>'td'))[13];	
      @child = $td1->content_list;
      my $volume = $child[0];	  	  

	        
      $info{$symbol, 'success'}   = 1;
      $info{$symbol, 'method'}    = 'Tradegate';
      $info{$symbol, 'symbol'}    = $isin;
	  $info{$symbol, 'name'}      = $sharename;
	  $info{$symbol, 'exchange'}  = $exchange;	  
      $info{$symbol, 'last'}      = $price;
      $info{$symbol, 'price'}     = $price;
      $info{$symbol, 'volume'}     = $volume;	  
      $info{$symbol, 'currency'}  = $currency;
#      $info{$symbol, 'date'}      = $date;
      $quoter->store_date(\%info, $symbol, {eurodate => $date});
    };
    if ($@) {
      $info{$symbol, 'success'}  = 0;
      $info{$symbol, 'errormsg'} = "Error retreiving $symbol: $@";
    }


}
  $ua->agent($agent);

  return wantarray() ? %info : \%info;
}

1;

=head1 NAME

Finance::Quote::Tradegate - Obtain quotes from S-Investor platform.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("Tradegate", "DE000ENAG999");  # Only query Tradegate
    %info = Finance::Quote->fetch("europe", "brd");     # Failover to other sources OK.

=head1 DESCRIPTION

This module fetches information from https://s-investor.de/, the investment platform
of the German Sparkasse banking group. It fetches share prices from tradegate,
a major German trading platform.

Suitable for shares and ETFs that are traded in Germany.

This module is loaded by default on a Finance::Quote object. It's also possible
to load it explicitly by placing "Tradegate" in the argument list to
Finance::Quote->new().

This module provides "Tradegate" and "europe" fetch methods.

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
volume


