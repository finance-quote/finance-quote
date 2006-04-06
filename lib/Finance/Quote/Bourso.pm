#!/usr/bin/perl -w
#    This module is based on the Finance::Quote::ASEGR & AEX modules
#
#    These codes has been modified by Dominique Corbex <domcox@sourceforge.net>
#    to be able to retreive stock information from http://www.boursorama.com 
#    in France.
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

require 5.005;

use strict;

package Finance::Quote::Bourso;

use vars qw($VERSION $Bourso_URL);

use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;


$VERSION='0.9.3';

my $Bourso_URL = 'http://www.boursorama.com/recherche/recherche.phtml';


sub methods { return ( france => \&bourso,
			bourso => \&bourso,
			europe => \&bourso); }
{ 
	my @labels = qw/name last date isodate p_change open high low close volume currency method exchange/;

	sub labels { return (france => \@labels,
			     bourso => \@labels,
			     europe => \@labels); } 
}

sub bourso {

	my $quoter = shift;
	my @stocks = @_;
	my (%info,$reply,$url,$te,$ts,$row,$style);
	my $ua = $quoter->user_agent();

	$url=$Bourso_URL;
	
	foreach my $stocks (@stocks)
	{
		$reply = $ua->request(GET $url.join('',"?searchKeywords=", $stocks));


		if ($reply->is_success) 
		{

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


			# date
			my ($date,$sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst);
			($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime(time);
			$year += 1900;
			$month += 1;
			$date=$month."/".$mday."/".$year;


			# Page style
			foreach $ts ($te->table_state(2, 0)){
				@rows=$ts->rows;
				$style=$rows[0][0];
			}

			SWITCH: for ($style){
			        /cours-action/ && do { 
					# page=action
					foreach $ts ($te->table_state(4, 0)){
						@rows=$ts->rows;
						foreach $row ($ts->rows) {
						ASSIGN:	for ( @$row[0] ){  
								/Cours/ && do {
									($info{$stocks, "last"}=@$row[2]) =~ s/[^0-9.-]*//g;
									$info{$stocks, "success"}=1;
									$info{$stocks, "exchange"}="www.boursorama.com";
									$info{$stocks, "method"}="bourso";
									$info{$stocks, "name"}=$stocks;
									$info{$stocks,"currency"}="EUR";
									$quoter->store_date(\%info, $stocks, {today => 1});
									# GnuCash
									$info{$stocks, "symbol"}=$stocks;
									last ASSIGN;
								};
								/Variation/ && do {
									($info{$stocks, "p_change"}=@$row[2]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
								/Volume/ && do {
									($info{$stocks, "volume"}=@$row[2]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
								/Ouverture/ && do {
									($info{$stocks, "open"}=@$row[2]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
								/ Haut/ && do {
									($info{$stocks, "high"}=@$row[2]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
								/ Bas/ && do {
									($info{$stocks, "low"}=@$row[2]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
#								/Cl?t. veille/
#								/Capital ?chang?/
								/Valorisation/ && do {
									($info{$stocks, "nav"}=@$row[2]) =~ s/M/000000/g;
									($info{$stocks, "nav"}=@$row[2]) =~ s/K/000/g;
									($info{$stocks, "nav"}=$info{$stocks, "nav"}) =~ s/[^0-9.]*//g;
									last ASSIGN;
								};
							}
						}
					}
					last SWITCH; 
				};
			        /cours-obligation/ && do { 
					# page=obligation
 					foreach $ts ($te->table_state(4, 0)){
						@rows=$ts->rows;
						foreach $row ($ts->rows) {

						ASSIGN:	for ( @$row[0] ){

								/Cours/ && do {
									($info{$stocks, "last"}=@$row[2]) =~ s/[^0-9.-]*//g;
									$info{$stocks, "success"}=1;
									$info{$stocks, "exchange"}="www.boursorama.com";
									$info{$stocks, "method"}="bourso";
									$info{$stocks, "name"}=$stocks;
									$info{$stocks,"currency"}="EUR";
									$quoter->store_date(\%info, $stocks, {today => 1});
									# GnuCash
									$info{$stocks, "symbol"}=$stocks;
									last ASSIGN;
								};
								/Variation/ && do {
									($info{$stocks, "p_change"}=@$row[2]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
								/Ouverture/ && do {
									($info{$stocks, "open"}=@$row[2]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
								/Haut/ && do {
									($info{$stocks, "high"}=@$row[2]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
								/ Bas/ && do {
									($info{$stocks, "low"}=@$row[2]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
							}
						}
					}
					last SWITCH; 
				};
			        /opcvm\/opcvm/ && do { 
					# page=opvcm
 					foreach $ts ($te->table_state(5, 1)){
						@rows=$ts->rows;
						foreach $row ($ts->rows) {

						ASSIGN:	for ( @$row[0] ) {

								/Valeur liquidative/ && do {
									($info{$stocks, "last"}=@$row[2]) =~ s/[^0-9.-]*//g;
									$info{$stocks, "success"}=1;
									$info{$stocks, "exchange"}="www.boursorama.com";
									$info{$stocks, "method"}="bourso";
									$info{$stocks, "name"}=$stocks;
									$info{$stocks,"currency"}="EUR";
									$quoter->store_date(\%info, $stocks, {today => 1});
									# GnuCash
									$info{$stocks, "symbol"}=$stocks;
									last ASSIGN;
								};
								/Variation Veille/ && do {
									($info{$stocks, "p_change"}=@$row[2]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
								/Date/ && do {
								        $quoter->store_date(\%info, $stocks, {eurodate => @$row[2]});
									last ASSIGN;
								};
							}
						} 
					}
					last SWITCH; 
				};
				/cours-warrant/ && do{ 
					# page=warrant
 					foreach $ts ($te->table_state(4, 0)){
						@rows=$ts->rows;
						foreach $row ($ts->rows) {

						ASSIGN:	for ( @$row[0] ) {

								/Cours/ && do {
									($info{$stocks, "last"}=@$row[2]) =~ s/[^0-9.-]*//g;
									$info{$stocks, "success"}=1;
									$info{$stocks, "exchange"}="www.boursorama.com";
									$info{$stocks, "method"}="bourso";
									$info{$stocks, "name"}=$stocks;
									$info{$stocks,"currency"}="EUR";
									$info{$stocks,"date"}=$date;
									# GnuCash
									$info{$stocks, "symbol"}=$stocks;
									last ASSIGN;
								};
								/Variation/ && do {
									($info{$stocks, "p_change"}=@$row[2]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
								/Ouverture/ && do {
									($info{$stocks, "open"}=@$row[2]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
								/Haut/ && do {
									($info{$stocks, "high"}=@$row[2]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
								/ Bas/ && do {
									($info{$stocks, "low"}=@$row[2]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
								/Volume/ && do {
									($info{$stocks, "volume"}=@$row[2]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
							}
						}
					} 
					last SWITCH; 
				};
			        /cours-indice/ && do { 
					# page=action
					foreach $ts ($te->table_state(4, 0)){
						@rows=$ts->rows;
						foreach $row ($ts->rows) {
						ASSIGN:	for ( @$row[0] ){  
								/Cours/ && do {
									($info{$stocks, "last"}=@$row[2]) =~ s/[^0-9.-]*//g;
									$info{$stocks, "success"}=1;
									$info{$stocks, "exchange"}="www.boursorama.com";
									$info{$stocks, "method"}="bourso";
									$info{$stocks, "name"}=$stocks;
									$info{$stocks,"currency"}="EUR";
									$info{$stocks,"date"}=$date;
									# GnuCash
									$info{$stocks, "symbol"}=$stocks;
									last ASSIGN;
								};
								/Variation/ && do {
									($info{$stocks, "p_change"}=@$row[2]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
								/Volume/ && do {
									($info{$stocks, "volume"}=@$row[2]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
								/Ouverture/ && do {
									($info{$stocks, "open"}=@$row[2]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
								/ Haut/ && do {
									($info{$stocks, "high"}=@$row[2]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
								/ Bas/ && do {
									($info{$stocks, "low"}=@$row[2]) =~ s/[^0-9.-]*//g;
									last ASSIGN;
								};
							}
						}
					}
					last SWITCH; 
				};
			        {
					$info {$stocks,"success"} = 0;
					$info {$stocks,"errormsg"} = "Error retreiving $stocks ";
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

Finance::Quote::Bourso Obtain quotes from Boursorama.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("bourso","ml");  # Only query Bourso
    %info = Finance::Quote->fetch("france","af"); # Failover to other sources OK. 

=head1 DESCRIPTION

This module fetches information from the "Paris Stock Exchange",
http://www.boursorama.com. All stocks are available. 

This module is loaded by default on a Finance::Quote object. It's 
also possible to load it explicity by placing "bourso" in the argument
list to Finance::Quote->new().

This module provides both the "bourso" and "france" fetch methods.
Please use the "france" fetch method if you wish to have failover
with future sources for French stocks. Using the "bourso" method
will guarantee that your information only comes from the Paris Stock Exchange.
 
Information obtained by this module may be covered by www.boursorama.com 
terms and conditions See http://www.boursorama.com/ for details.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::Bourso :
name, last, date, p_change, open, high, low, close, nav,
volume, currency, method, exchange, symbol.

=head1 SEE ALSO

Boursorama (french web site), http://www.boursorama.com

=cut

	
