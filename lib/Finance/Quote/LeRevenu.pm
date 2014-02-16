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

$VERSION = '1.19';

my $LR_URL = 'http://bourse.lerevenu.com/recherchenom.hts';


sub methods { return ( france => \&lerevenu,
			lerevenu => \&lerevenu); }
{
	my @labels = qw/name last date isodate p_change open high low close volume currency method exchange/;

	sub labels { return (france => \@labels,
			     lerevenu => \@labels); }
}

sub lerevenu {

	my $quoter = shift;
	my @stocks = @_;
	my (%info,$reply,$url,$te,$ts,$row,$style);
	my $ua = $quoter->user_agent();

	foreach my $stocks (@stocks)
	{
		$url="$LR_URL?recherchenom=$stocks&p=20";

		$reply = $ua->request(GET $url);

		if ($reply->is_success)
		{
			# print STDERR $reply->content,"\n";

			$te= new HTML::TableExtract( );

			$te->parse($reply->content);

			unless ( $te->tables)
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
#			foreach $ts ($te->table_states) {
#				print "Table (", join(',', $ts->coords), "):\n";
#				foreach $row ($ts->rows) {
#					print join(',', @$row), "\n";
#     				}
#    			}


			# style
			foreach $ts ($te->table_state(2, 0)){
				@rows=$ts->rows;
				($style=$rows[1][1]) =~ s/[>\n\s]*//g;
			}


			SWITCH: for ($style){
				# style=stock
			        /Actions/ && do {
					foreach $ts ($te->table_state(5, 0)){
						@rows=$ts->rows;
						$info{$stocks, "name"}=$rows[0][0];
						}
					foreach $ts ($te->table_state(8, 1)){
						@rows=$ts->rows;
						foreach $row ($ts->rows) {
						ASSIGN:	for ( @$row[0] ) {
								/Dernier/ && do {
									($info{$stocks, "last"}=@$row[1]) =~ s/[^0-9.-]*//g;
									($info{$stocks, "close"}=@$row[2]) =~ s/[^0-9.-]*//g;
									$info{$stocks, "success"}=1;
									$info{$stocks, "exchange"}="Euronext Paris";
									$info{$stocks, "method"}="lerevenu";
									$info{$stocks,"currency"}="EUR";
									last ASSIGN;
								};
								/Date/ && do {
									$quoter->store_date(\%info, $stocks, {eurodate => @$row[1]});
									last ASSIGN;
								};
								/Var %/ && do {
									($info{$stocks, "p_change"}=@$row[1]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
								/Volume/ && do {
									($info{$stocks, "volume"}=@$row[1]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
								/Premier/ && do {
									($info{$stocks, "open"}=@$row[1]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
								/ Haut/ && do {
									($info{$stocks, "high"}=@$row[1]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
								/ Bas/ && do {
									($info{$stocks, "low"}=@$row[1]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
							}
						}
					}
					foreach $ts ($te->table_state(6, 5)){
						@rows=$ts->rows;
						foreach $row ($ts->rows) {
						ASSIGN:	for ( @$row[0] ){
								/Isin/ && do {
									# GnuCash
									$info{$stocks, "symbol"}=@$row[1];
									last ASSIGN;
								};
							}
					    }
					}
					last SWITCH;
				};
				# style=bond
			       	/Obligations/ && do {
					foreach $ts ($te->table_state(5, 0)){
						@rows=$ts->rows;
						$info{$stocks, "name"}=$rows[0][0];
						}
					foreach $ts ($te->table_state(8, 0)){
						@rows=$ts->rows;
						foreach $row ($ts->rows) {
							($info{$stocks, "last"}=@$row[1]) =~ s/[^0-9.-]*//g;
							($info{$stocks, "close"}=@$row[1]) =~ s/[^0-9.-]*//g;
							$info{$stocks, "success"}=1;
							$info{$stocks, "exchange"}="Euronext Paris";
							$info{$stocks, "method"}="lerevenu";
							$info{$stocks,"currency"}="EUR";
						}
					}
 					foreach $ts ($te->table_state(7, 1)){
						@rows=$ts->rows;
						foreach $row ($ts->rows) {
						ASSIGN:	for ( @$row[0] ){
								/Date/ && do {
									$quoter->store_date(\%info, $stocks, {eurodate => @$row[1]});
									last ASSIGN;
								};
								/Var %/ && do {
									($info{$stocks, "p_change"}=@$row[1]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
								/Volume/ && do {
									($info{$stocks, "volume"}=@$row[1]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
								/Premier/ && do {
									($info{$stocks, "open"}=@$row[1]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
								/ haut/ && do {
									($info{$stocks, "high"}=@$row[1]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
								/ bas/ && do {
									($info{$stocks, "low"}=@$row[1]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
							}
						}
					}
					foreach $ts ($te->table_state(8, 3)){
						@rows=$ts->rows;
						foreach $row ($ts->rows) {
						ASSIGN:	for ( @$row[0] ){
								/Isin/ && do {
									# GnuCash
									$info{$stocks, "symbol"}=@$row[1];
									last ASSIGN;
								};
							}
						}
					}
					last SWITCH;
				};
				# style=fund
			        /SICAVetFCP/ && do {
					my $myquote; my @mycurrency;
					foreach $ts ($te->table_state(6, 0)){
						@rows=$ts->rows;
						$info{$stocks, "name"}=$rows[0][0];
						($info{$stocks, "last"}=$rows[0][2]) =~ s/[^0-9.-]*//g;
						$info{$stocks, "success"}=1;
						$info{$stocks, "exchange"}="Euronext Paris";
						$info{$stocks, "method"}="lerevenu";
						$myquote=$rows[0][2] ;
						@mycurrency= split / /, $myquote;
						($info{$stocks,"currency"}=$mycurrency[1]) =~ s/[\W]*//g ;
						$quoter->store_date(\%info, $stocks, {eurodate => $rows[0][1]});
						($info{$stocks, "p_change"}=$rows[2][2])=~ s/[^0-9.-]*//g;
						}
					foreach $ts ($te->table_state(9, 7)){
						@rows=$ts->rows;
						foreach $row ($ts->rows) {
						ASSIGN:	for ( @$row[0] ){
								/Actif/ && do {
									my $nav;
									$nav=@$row[1];
									$nav =~ s/[^0-9.]*//g;
									($info{$stocks, "nav"}=($nav * 1000000));
									last ASSIGN;
								};
							}
						}
					}
					foreach $ts ($te->table_state(9, 9)){
						@rows=$ts->rows;
						foreach $row ($ts->rows) {
						ASSIGN:	for ( @$row[0] ){
								/ISIN/ && do {
									# GnuCash
									($info{$stocks, "symbol"}=@$row[1]) =~ s/\s*//g;
									last ASSIGN;
								};
							}
						}
					}
					last SWITCH;
				};
				# style=warrant
				/Bons&Warrants/ && do {
					foreach $ts ($te->table_state(5, 0)){
						@rows=$ts->rows;
						$info{$stocks, "name"}=$rows[0][0];
						}
 					foreach $ts ($te->table_state(7, 1)){
						@rows=$ts->rows;
						foreach $row ($ts->rows) {
						ASSIGN:	for ( @$row[0] ){
								/Dernier/ && do {
									($info{$stocks, "last"}=@$row[1]) =~ s/[^0-9.-]*//g;
									($info{$stocks, "close"}=@$row[1]) =~ s/[^0-9.-]*//g;
									$info{$stocks, "success"}=1;
									$info{$stocks, "exchange"}="Euronext Paris";
									$info{$stocks, "method"}="lerevenu";
									$info{$stocks,"currency"}="EUR";
									last ASSIGN;
								};
								/Date/ && do {
									$quoter->store_date(\%info, $stocks, {eurodate => @$row[1]});
									last ASSIGN;
								};
								/Var %/ && do {
									($info{$stocks, "p_change"}=@$row[1]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
								/Volume/ && do {
									($info{$stocks, "volume"}=@$row[1]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
								/Premier/ && do {
									($info{$stocks, "open"}=@$row[1]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
								/ Haut/ && do {
									($info{$stocks, "high"}=@$row[1]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
								/ Bas/ && do {
									($info{$stocks, "low"}=@$row[1]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
							}
						}
					foreach $ts ($te->table_state(6, 8)){
						@rows=$ts->rows;
						foreach $row ($ts->rows) {
						ASSIGN:	for ( @$row[0] ){
								/Isin/ && do {
									# GnuCash
									$info{$stocks, "symbol"}=@$row[1];
									last ASSIGN;
								};
							}
						}

					    }
					}
					last SWITCH;
				};
				# style=indice
			        /Indices/ && do {
					foreach $ts ($te->table_state(5, 0)){
						@rows=$ts->rows;
						$info{$stocks, "name"}=$rows[0][0];
						}
					foreach $ts ($te->table_state(7, 1)){
						@rows=$ts->rows;
						foreach $row ($ts->rows) {
						ASSIGN:	for ( @$row[0] ){
								/Dernier/ && do {
									($info{$stocks, "last"}=@$row[1]) =~ s/[^0-9.-]*//g;
									($info{$stocks, "close"}=@$row[1]) =~ s/[^0-9.-]*//g;
									$info{$stocks, "success"}=1;
									$info{$stocks, "exchange"}="Euronext Paris";
									$info{$stocks, "method"}="lerevenu";
									$info{$stocks,"currency"}="EUR";
									last ASSIGN;
								};
								/Date/ && do {
									$quoter->store_date(\%info, $stocks, {eurodate => @$row[1]});
									last ASSIGN;
								};
								/Var %/ && do {
									($info{$stocks, "p_change"}=@$row[1]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
								/Premier/ && do {
									($info{$stocks, "open"}=@$row[1]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
								/ Haut/ && do {
									($info{$stocks, "high"}=@$row[1]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
								/ Bas/ && do {
									($info{$stocks, "low"}=@$row[1]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
							}
						}
					foreach $ts ($te->table_state(7, 2)){
						@rows=$ts->rows;
						foreach $row ($ts->rows) {
						ASSIGN:	for ( @$row[0] ){
								/Isin/ && do {
									# GnuCash
									$info{$stocks, "symbol"}=@$row[1];
									last ASSIGN;
								};
							}
						}
					    }
					}
					last SWITCH;
				};
			        {
					$info {$stocks,"success"} = 0;
					$info {$stocks,"errormsg"} = "Parse error";
				}
			}


		}
		else {
     			$info{$stocks, "success"}=0;
			$info{$stocks, "errormsg"}="Error retreiving $stocks ";
   		}
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
