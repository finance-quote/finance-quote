#!/usr/bin/perl -w
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@cpan.org>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#    Copyright (C) 2001, Rob Sessink <rob_ses@users.sourceforge.net>
#    Copyright (C) 2005, Morten Cools <morten@cools.no>
#    Copyright (C) 2006, Dominique Corbex <domcox@sourceforge.net>
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
#
# This code derived from Padzensky's work on package Finance::YahooQuote,
# but extends its capabilites to encompas a greater number of data sources.
#

require 5.005;

use strict;

package Finance::Quote::LeRevenu;

use vars qw($VERSION $LR_URL);

use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;

$VERSION = '1.17';

my $LR_URL = 'http://bourse.lerevenu.com/v2/recherchenom.hts';


sub methods { return ( france => \&pre_france,
		       lerevenu => \&pre_lerevenu); }
{ 
	my @labels = qw/name last date isodate p_change open high low close volume currency method exchange/;

	sub labels { return (france => \@labels,
			     lerevenu => \@labels); } 
}

sub pre_france {
	unshift(@_,"&p=20");
	&lerevenu;
}

sub pre_lerevenu {
	unshift(@_,"");
	&lerevenu;
}

sub lerevenu {
	my $ext_url = shift;
	my $quoter = shift;
	my @stocks = @_;
	my (%info,$reply,$url,$te,$ts,$row,$style,@test,$stock_number);
	my $ua = $quoter->user_agent();

	foreach my $stocks (@stocks)
	{
		$url="$LR_URL?recherchenom=$stocks".$ext_url;
	
		$reply = $ua->request(GET $url);  

		if ($reply->is_success) 
		{
			$te= new HTML::TableExtract( );

			$te->parse($reply->content);

			@test = split /instrument/, $reply->content;
			@test = split /:/,$test[0];
			($stock_number=$test[1]) =~ s/[^0-9]//g;

			if ($stock_number == 1)
			{

				@test = split /<A/, $reply->content;
				@test = split /<\/A/,$test[1];

				($test[0]) =~ s/^(.+)(class="efnf_donnees" href=")//g;
				($test[0]) =~ s/(")(.+)$//g;

				$url="http://bourse.lerevenu.com/v2/".$test[0];	
				($url) =~ s/http:\/\/www.lerevenu.com\/ajax\/getFiche.php/action.hts/;
			
				$reply = $ua->request(GET $url);  

				if ($reply->is_success) 
				{

					$te= new HTML::TableExtract( );

					$te->parse($reply->content);

					unless ($te->tables)
					{
						$info {$stocks,"success"} = 0;
						$info {$stocks,"errormsg"} = "Stock name $stocks not found";
						next;
					}

					my @rows;
					unless (@rows = $te->rows)
					{
						$info {$stocks,"success"} = 0;
						$info {$stocks,"errormsg"} = "Parse error";
						next;
					}

					# debug
	#				foreach $ts ($te->table_states) {
	#					print "Table (", join(',', $ts->coords), "):\n";
	#					foreach $row ($ts->rows) {
	#						print join(',', @$row), "\n";
	#					}
	#				}

					# style

					($style=$url) =~ s/^(.+)(v2\/)//g;
					($style) =~ s/(.hts)(.+)$//g;

					SWITCH: for ($style){
						# style=stock
						/action/ && do {
							foreach $ts ($te->table_state(2, 0)){
								@rows=$ts->rows;
								$info{$stocks, "name"}=$rows[0][0];
								$info{$stocks, "exchange"}=$rows[3][1];
								($info{$stocks, "symbol"}=$rows[3][0]) =~ s/\W(.+)$//g;
								} 
							foreach $ts ($te->table_state(6, 1)){
								@rows=$ts->rows;
								$info{$stocks, "last"}=$rows[2][1];
								$info{$stocks, "success"}=1;
								$info{$stocks, "method"}="lerevenu";
								$info{$stocks,"currency"}=$rows[9][1];
								$quoter->store_date(\%info, $stocks, {eurodate => $rows[0][1]});
								$info{$stocks,"p_change"}=$rows[3][1];
								$info{$stocks,"volume"}=$rows[7][1];
								$info{$stocks,"open"}=$rows[4][1];
								$info{$stocks,"high"}=$rows[5][1];
								$info{$stocks,"low"}=$rows[6][1];
								}
							last SWITCH; 
							};
						# style=bond
						/obligation/ && do {
							foreach $ts ($te->table_state(2, 0)){
								@rows=$ts->rows;
								$info{$stocks, "name"}=$rows[0][0];
								$info{$stocks, "exchange"}=$rows[3][1];
								($info{$stocks, "symbol"}=$rows[3][0]) =~ s/\W(.+)$//g;
								($info{$stocks,"currency"}=$rows[0][1]) =~ s/[^A-Z]//g;

								} 
							foreach $ts ($te->table_state(4, 0)){
								@rows=$ts->rows;
								$info{$stocks, "last"}=$rows[0][1];
								}
							foreach $ts ($te->table_state(3, 0)){
								@rows=$ts->rows;
								$info{$stocks, "success"}=1;
								$info{$stocks, "method"}="lerevenu";

								$quoter->store_date(\%info, $stocks, {eurodate => $rows[0][1]});
								$info{$stocks,"p_change"}=$rows[3][1];
								$info{$stocks,"volume"}=$rows[7][1];
								$info{$stocks,"open"}=$rows[4][1];
								$info{$stocks,"high"}=$rows[5][1];
								$info{$stocks,"low"}=$rows[6][1];
								}
							last SWITCH; 
							};
						# style=fund
						/opcvm/ && do {
							$info{$stocks, "success"}=1;
							$info{$stocks, "method"}="lerevenu";
							foreach $ts ($te->table_state(3, 0)){
								@rows=$ts->rows;
								$info{$stocks, "name"}=$rows[0][0];
								$info{$stocks, "symbol"}=$rows[2][1];
								($info{$stocks,"currency"}=$rows[0][1]) =~ s/[^A-Z]//g;
								($info{$stocks,"last"}=$rows[0][1]) =~ s/[^0-9|.]//g;
								$info{$stocks,"p_change"}=$rows[0][2];
								$quoter->store_date(\%info, $stocks, {eurodate => $rows[2][3]});
								} 
							foreach $ts ($te->table_state(7, 7)){
								@rows=$ts->rows;
								my $nav;
								($nav=$rows[0][1]) =~ s/[^0-9.]*//g;
								($info{$stocks,"nav"}=($nav * 1000000));
								}
							last SWITCH; 
							};
						#style=warrant
						/warrant/ && do {
							foreach $ts ($te->table_state(2, 0)){
								@rows=$ts->rows;
								$info{$stocks, "name"}=$rows[0][0];
								$info{$stocks, "exchange"}=$rows[3][1];
								($info{$stocks, "symbol"}=$rows[3][0]) =~ s/\W(.+)$//g;
								} 
							foreach $ts ($te->table_state(3, 0)){
								@rows=$ts->rows;
								$info{$stocks, "last"}=$rows[2][1];
								$info{$stocks, "success"}=1;
								$info{$stocks, "method"}="lerevenu";
								$info{$stocks,"currency"}=$rows[9][1];
								$quoter->store_date(\%info, $stocks, {eurodate => $rows[0][1]});
								$info{$stocks,"p_change"}=$rows[3][1];
								$info{$stocks,"volume"}=$rows[7][1];
								$info{$stocks,"open"}=$rows[4][1];
								$info{$stocks,"high"}=$rows[5][1];
								$info{$stocks,"low"}=$rows[6][1];
								}
							last SWITCH; 
							};
						#style=indice
						/indice/ && do {
							foreach $ts ($te->table_state(2, 0)){
								@rows=$ts->rows;
								$info{$stocks, "name"}=$rows[0][0];
								$info{$stocks, "exchange"}=$rows[3][1];
								($info{$stocks, "symbol"}=$rows[3][0]) =~ s/\W(.+)$//g;
								} 
							foreach $ts ($te->table_state(5, 1)){
								@rows=$ts->rows;
								$info{$stocks, "last"}=$rows[2][1];
								$info{$stocks, "success"}=1;
								$info{$stocks, "method"}="lerevenu";
								$quoter->store_date(\%info, $stocks, {eurodate => $rows[0][1]});
								$info{$stocks,"p_change"}=$rows[3][1];
								$info{$stocks,"volume"}=$rows[7][1];
								$info{$stocks,"open"}=$rows[4][1];
								$info{$stocks,"high"}=$rows[5][1];
								$info{$stocks,"low"}=$rows[6][1];
								}
							last SWITCH; 
							};
						{
							$info {$stocks,"success"} = 0;
							$info {$stocks,"errormsg"} = "Parse error SWITCH";
						}
					}


				} 
				else {
		     			$info{$stocks, "success"}=0;
					$info{$stocks, "errormsg"}="Error retreiving $stocks ";
	   			}; 
			}
			else {
	     			$info{$stocks, "success"}=0;
				$info{$stocks, "errormsg"}="Error retreiving $stocks ";
	   		}; 
		} 
		else {
     			$info{$stocks, "success"}=0;
			$info{$stocks, "errormsg"}="Error retreiving $stocks ";
   		};
 	
	} 

 	return wantarray() ? %info : \%info;
 	return \%info;
}
1;

=head1 NAME

Finance::Quote::LeRevenu Obtain quotes from http://bourse.lerevenu.com.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("LeRevenu","FR0000031122");  # Only query LeRevenu
    %info = Finance::Quote->fetch("france","ml"); # Failover to other sources OK. 

=head1 DESCRIPTION

This module fetches information from the "Paris Stock Exchange",
http://bourse.lerevenu.com. All stocks are available. 

This module is loaded by default on a Finance::Quote object. It's 
also possible to load it explicity by placing "LeRevenu" in the argument
list to Finance::Quote->new().

This module provides both the "lerevenu" and "france" fetch methods.
Please use the "france" fetch method if you wish to have failover
with future sources for French stocks. Using the "lerevenur" method
will guarantee that your information only comes from the Paris Stock Exchange.
 
Information obtained by this module may be covered by http://bourse.lerevenu.com 
terms and conditions See http://bourse.lerevenu.com for details.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::LeRevenu :
name, last, date, p_change, open, high, low, close, 
volume, currency, method, exchange.

=head1 SEE ALSO

Le Revenu, http://bourse.lerevenu.com

=cut

	
