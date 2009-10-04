#!/usr/bin/perl -w
#
# HU.pm
#
# Version 0.2 - Download of Hungarian (HU) stocks from www.MAGYARTOKEPIAC.hu
# This version based on ZA.pm module
#
# Zoltan Levardy <zoltan at levardy dot org>
# 2008,2009

# Comments on work in progress by Zoltan posted on 3 Jul 2009
# Current implementation does the next steps:
# (1) trying to find ISIN online.
# (2) reading stock page to get quote
# (3) if failed then trying to find as ETF on different page
# (4) if not found as ETF, then trying to get ISIN from local map, and reading stock page again.

package Finance::Quote::HU;
require 5.004;

use strict;
use vars qw /$VERSION/ ;

use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;
use Encode;
use Storable qw(dclone);

$VERSION = '1.17';

my %MONTHS = ( 
	"JAN","01","FEB","02","MAR","03","APR","04","MAY","05","JUN","06","JUL","07","AUG","08","SEP","09","OCT","10","NOV","11","DEC","12");
my %XMONTHS = ( 
	"01","JAN","02","FEB","03","MAR","04","APR","05","MAY","06","JUN","07","JUL","08","AUG","09","SEP","10","OCT","11","NOV","12","DEC");


### STOCK urls
my $MAGYARTOKEPIAC_MAINURL = ("http://www.magyartokepiac.hu/");
my $MAGYARTOKEPIAC_URL = ($MAGYARTOKEPIAC_MAINURL."cegadatok/reszletek.php");
### ETF,Funds urls
my $BAMOSZ_MAINURL = ("http://www.bamosz.hu/");
my $BAMOSZ_URL = ($BAMOSZ_MAINURL."adatok/napiadatok/index.ind?do=show");
### ISIN urls:
my $BET_MAINURL = ("http://www.bet.hu/");
my $BET_ISINURL = ($BET_MAINURL."topmenu/kereskedesi_adatok/product_search");
#print "[debug]: URL=", $MAGYARTOKEPIAC_URL, "\n";
#print "[debug]: URL=", $BAMOSZ_URL, "\n";

sub methods {
   return (hu => \&main, hungary => \&main, bse => \&main, bux => \&main);
}

sub labels {
   my @labels = qw/method source name symbol currency last date isodate high low p_change/;
   return (hu => \@labels, hungary => \@labels, magyartokepiac => \@labels, bse => \@labels, bux => \@labels);
}   

### main program
######################
sub main {
	my $quoter = shift;
   my @symbols = @_;
   my %info;

	
	#print "[debug]: main() symbols=",@symbols,"\n";
   return unless @symbols;
	
	my $ua = $quoter->user_agent;
	my $isin;
	
	foreach my $symbol (@symbols) {
		#print "[debug]: main() ticker=",$symbol,"\n";
		my %iinfo = ticker2isin($symbol,$ua);
		$isin=$iinfo{$symbol,"isin"};
		#print "[debug]: isin found: ", $isin, "\n";
		#$isin = ticker2isin_by_map($symbol);
		#print "[debug]: hungary() ticker=",$symbol,", isin=",$isin,"\n";
		
		#TODO: call magyartokepiac() here
		my %minfo = magyartokepiac($quoter,$ua,$isin,$symbol);
		#print "[debug] main(): ",$minfo{$symbol,"success"},"\n";
		if ($minfo{$symbol,"success"}) {
			#%info = %minfo;
			#%info = %{ dclone(\%minfo) };
			#append minfo to info:
			%info = (%minfo, %info);
			#print "[debug] main: minfo copied into info\n";
		} 
		else {
			### in some cases the ISIN provided by BET.HU is good, but the quotes page using an old one a MAGYARTOKEPIAC.HU
			my $isin_alt = ticker2isin_by_map($symbol);
			if (!$isin || ($isin ne $isin_alt)) {
				#print "[debug]: alternate lookup of isin: $isin\n";
				$isin=$isin_alt;
				my %info2 = magyartokepiac($quoter,$ua,$isin,$symbol);
				unless ($info2{$symbol,"success"}) {
					# print STDERR "Alternate ISIN pickup also not working...";
          $info2{$symbol,"errormsg"}="Alternate ISIN pickup also not working..." ;
          %info = (%info2, %info);
				} else {
					#%info = dclone %info2;
					#print "[debug]: new isin found: $isin_alt\n";
					#%info = %{ dclone(\%info2) };
					%info = (%info2, %info);
				}
			}
		}
	}
	#print "[debug] main(): done.\n\n";
	
	return wantarray() ? %info : \%info;
}

### this method is fetching STOCK quotes by ISIN - www.magyartokepiac.hu
#############################################
sub magyartokepiac {

	#print "[debug]: magyartokepiac()";
	my $quoter = $_[0];
	my $ua = $_[1];
	my $isin = $_[2];
	my $symbol = $_[3];

   my %minfo;

	if (!$isin) {
		$minfo{$symbol, "success"} = 0;
		$minfo{$symbol, "errormsg"} = "No ISIN specified";
    return wantarray() ? %minfo : \%minfo;
	}

	my ($te, $ts, $row);
   my @rows;

	my $url = $MAGYARTOKEPIAC_URL."?isin=".$isin;
	#print "[debug]: ", $url, "\n";
	my $response = $ua->request(GET $url);
	#print "[debug]: ", $response->content, "\n";
	
	if (!$response->is_success) {
		$minfo{$symbol, "success"} = 0;
		$minfo{$symbol, "errormsg"} = "Error contacting URL";
    return wantarray() ? %minfo : \%minfo;
#		next;
	}

	#PARSING
	$te = HTML::TableExtract->new( depth => 1, count => 0 );
	$te->parse(decode_utf8($response->content));
	foreach $ts ($te->tables) {
		my $cell = $ts->rows->[0][0];
		my $status = 1;
		my $price = 0;
		my $close = 0;
		
		my $c=0;
		foreach (split(/\n/,$cell)) {
			my $line = trim($_);
			$c++;
			#if ($line ne "") { print " [debug] myline ",$c,"::",$line; }
			
			if ($c == 4) { #4th line is the name
				$line =~ s/\(.*folyamok\)//;
				#print "[debug]: name=",$line,"\n";
				$minfo{$symbol, "name"}  = $line;
				
				if (!$line) {
					#print "[debug]: name is empty!\n";
					$status = 0;
					$minfo{$symbol, "errormsg"} = "The provided ISIN/TICKER is invalid. Your symbol was '$symbol'.";
				}
			}
			if ($status && $c == 6) { #6th "last"
				$price = $line;
				$minfo{$symbol, "last"}  = $price;
				$minfo{$symbol, "price"}  = $price;
				#$info{$symbol, "nav"}  = $line;
			}
			if ($status && $c == 7) { #7th "net" ("p_change")
				my @values = split('\s\(.?\s', $line);
				#print "[debug]: line=",$line,"\n";
				#print "[debug]: v[0]=",$values[0],"\n";
				$minfo{$symbol, "net"}  = $values[0];
				#print "[debug]: v[1]=",$values[1],"\n";
				$values[1] =~ s/\s%\)//;
				#print "[debug]: v[1]=",$values[1],"\n";
				$minfo{$symbol, "p_change"}  = $values[1];
			}
			if ($status && $c == 8) { #7th "date" "time"
				my @values = split('\s', $line);
				#$info{$symbol, "date"}  = $MONTHS{uc $values[1]}."/".$values[0]."/".substr($values[2],2);
				$minfo{$symbol, "time"}  = $values[3];

				$quoter->store_date(\%minfo, $symbol, {eurodate => $line});
				
				#my @values = split('\s', $line);
				#print "SHARE DATE: ",$MONTHS{uc $values[1]}."/".$values[0]."/".substr($values[2],2)." ".$values[3],"\n";
				#print "SHARE DATE: '",$line,"'\n";
			}
			if ($status && $c == 13) { #13th "open"
				$minfo{$symbol, "open"}  = $line;
			}
			if ($status && $c == 15) { #15th "volume"
				$minfo{$symbol, "volume"}  = $line;
			}
			if ($status && $c == 17) { #17th "pe"
				$minfo{$symbol, "pe"}  = $line;
			}
			if ($status && $c == 20) { #20th "close"
				$close = $line;
				$minfo{$symbol, "close"}  = $close;
			}
			if ($status && $c == 22) { #22th "avg_vol"
				$minfo{$symbol, "avg_vol"}  = $line;
			}
			if ($status && $c == 24) { #24th "eps"
				$minfo{$symbol, "eps"}  = $line;
			}
			if ($status && $c == 27) { #27th "high"
				$minfo{$symbol, "high"}  = $line;
			}
			if ($status && $c == 34) { #34th "eps"
				$minfo{$symbol, "low"}  = $line;
			}
			if ($status && $c == 38) { #38th "cap"
				$minfo{$symbol, "cap"}  = $line;
			}
			
			#if ($line ne "") { print " ==>> ",$line, [debug]"\n"; }
			
		}
		
		#POST PROCESSING (out of trade price is the last closing price):
		if ($price eq 0) {
			$minfo{$symbol, "price"} = $close;
		}

		#if status is 0, then going to find on another website:
		if ($status) {
			# GENERAL FIELDS
			$minfo{$symbol, "method"} = "magyartokepiac";
			$minfo{$symbol, "symbol"} = $symbol;
			$minfo{$symbol, "currency"} = "HUF";
			$minfo{$symbol, "source"} = $MAGYARTOKEPIAC_MAINURL;
		} else {
			#print "[debug] magyartokepiac(): call bamosz(): isin=",$isin,"\n";
			my %binfo = bamosz($quoter,$ua,$isin);
			$status = $binfo{$isin,"success"};
			# GENERAL FIELDS
			$minfo{$symbol, "method"} = "bamosz";
			$minfo{$symbol, "symbol"} = $isin;
			$minfo{$symbol, "currency"} = "HUF";
			$minfo{$symbol, "source"} = $BAMOSZ_MAINURL;
			#LAST and DATE:
			if ($status) {
				$minfo{$symbol, "date"} = $binfo{$isin,"date"};
				$minfo{$symbol, "isodate"} = $binfo{$isin,"isodate"};
				#$info{$symbol, "time"} = $binfo{$isin,"time"};
				$minfo{$symbol, "last"} = $binfo{$isin,"last"};
				$minfo{$symbol, "price"} = $binfo{$isin,"last"};
				$minfo{$symbol, "volume"} = $binfo{$isin,"volume"};
				$minfo{$symbol, "nav"} = $binfo{$isin,"nav"};
				$minfo{$symbol, "net"} = $binfo{$isin,"net"};
				$minfo{$symbol, "p_change"} = $binfo{$isin,"p_change"};
				#print "\n",$binfo{$isin,"last"}," ",$binfo{$isin,"date"},"\n";
			}
		}

		$minfo{$symbol, "success"} = $status;
		#print "[debug]: status set to ",$status,"\n";
	}

	return wantarray() ? %minfo : \%minfo;
}

### this method is about fetching ETF, funds by ISIN
###############################
sub bamosz {
	my $quoter = $_[0];
	my $ua = $_[1];
	my $x = $_[2];
	#print "[debug]: bamosz(): param=",$x,"\n";

   my %binfo;
   my ($te, $ts, $row);
	my @rows;
	
   return unless $x;

	my $url = $BAMOSZ_URL."&fund_id=".$x.bamosz_date()."&show=arf&show=nee&show=cf&show=d_cf";
	#&fund_id=HU0000704366&from_year=2008&from_month=12&from_day=3&until_year=2008&until_month=12&until_day=4&show=arf"
	#print "[debug]: bamosz(): ", $url, "\n";
	my $resp = $ua->request(POST $url);
	#print "[debug]: bamosz() :", $resp->content, "\n";
	
	#DiGGING SESSION ID:
	my $data = $resp->content;
	my $key="targetString = '\/adatok\/napiadatok\/index.ind\?isFlashCompliant=";
	my $sessionid= substr( $data, index($data, $key)+length($key));
	$sessionid= substr( $sessionid, 0, index ($sessionid, "\n"));
	$sessionid= substr( $sessionid, index($sessionid,'session_id='));
	$sessionid= substr( $sessionid, 0, index($sessionid,"';"));
	#print "\nsession-id=$sessionid.\n";
	
	#CALL PAGE WITH SESSION AGAIN:
	my $response = $ua->get($url."&isFlashCompliant=false&amp;".$sessionid);
	
	#print "\n",$url."&isFlashCompliant=false;".$sessionid,"\n";
	#print "\nPAGE:\n",$response->content,"\n";
		
	if (!$response->is_success) {
		#print STDERR  "[debug] bamosz(): page unavailable\n";
		$binfo{$x, "success"} = 0;
		$binfo{$x, "errormsg"} = "Error contacting URL";
		return;
	}
	
	#PARSING
	$te = new HTML::TableExtract()->new( depth => 2, count => 2 );
	$te->parse(decode_utf8($response->content));
	#print "[debug]: (parsed HTML)",$te, "\n";

	unless ($te->first_table_found()) {
		#print STDERR  "[debug] bamosz(): no tables on this page\n";
		$binfo{$x, "success"}  = 0;
		$binfo{$x, "errormsg"} = "Parse error";
		return;
	}
	
	# Debug to dump all tables in HTML...
   # print "\n \n \n \n[debug]: ++++ ==== ++++ ==== ++++ ==== ++++ ==== START OF TABLE DUMP ++++  ==== \n \n \n \n";
	# foreach $ts ($te->table_states) {;
		# printf "\n \n \n \n[debug]: //// //// \\\\ START OF TABLE %d,%d //// \\\\ //// \\\\ \n \n \n \n",$ts->depth, $ts->count;
       # foreach $row ($ts->rows) {
			# print "[debug]: ", $row->[0], " | ", $row->[1], " | ", $row->[2], " | ", $row->[3], "\n";
       # }
   # }
   # print "\n \n \n \n[debug]: ++++ ==== ++++ ==== ++++ ==== ++++ ==== END OF TABLE DUMP ++++ ==== \n \n \n \n";

	foreach $ts ($te->tables) {
		my $lastdate = $ts->rows->[1][0];
		my $lastrate = bamosz_number( $ts->rows->[1][1] );
		#print "[debug]: bamosz(): last available price is $lastrate at $lastdate.\n";
		$binfo{$x, "last"} = $lastrate;
		#$binfo{$x, "date"} = substr($lastdate,5,2)."/".substr($lastdate,8,2)."/".substr($lastdate,2,2);
		my $lastfulldate = substr($lastdate,8,2)." ".$XMONTHS{substr($lastdate,5,2)}." ".substr($lastdate,0,4); #." 16:00";
		#print "\n",$x,": ",$lastdate," >> '",$lastfulldate,"'\n";
		$quoter->store_date(\%binfo, $x, {eurodate => $lastfulldate});
		#$binfo{$x, "isodate"} = substr($lastdate,0,4)."-".substr($lastdate,5,2)."-".substr($lastdate,8,2);
		#print "isodate: ",substr($lastdate,0,4)."-".substr($lastdate,5,2)."-".substr($lastdate,8,2);
		
		my $lastnav = bamosz_number( $ts->rows->[1][2] );
		my $lastnet = bamosz_number( $ts->rows->[1][3] );
		my $lastpch = bamosz_number( $ts->rows->[1][4] );
		#print "[debug]: bamosz(): lastnav=$lastnav, lastnet=$lastnet, lastpch=$lastpch, volume=",($lastnet*$lastrate),".\n";
		$binfo{$x, "nav"} = $lastnav;
		$binfo{$x, "net"} = $lastnet;
		$binfo{$x, "volume"} = $lastnet*$lastrate;
		$binfo{$x, "p_change"} = $lastpch;
		
		#DONE:
		$binfo{$x, "success"}  = 1;
	}

	return %binfo;
}

sub bamosz_number {
	my $x = $_[0];

	#if ( index( $lastrate, ".")<0 ) { $lastrate =~ s/,/./; } 
	if ($x =~ m/(\d*.?\d*)*,?\d*%?$/) {
		#print "\nHUN:$x\n";
		$x =~ s/\.//g;
		$x =~ s/,/\./; 
	}
	$x =~ s/%$//;
	#print "TEST:$x\n";
	#convert HTML minus, to number minus:
	if ($x =~ m/^\D+\d+(.?\d)/) {
		$x =~ s/^\D+/-/;
	}
	#print "RET:$x\n";
	return $x;
}

sub bamosz_date {
	# "&from_year=2008&from_month=12&from_day=3&until_year=2008&until_month=12&until_day=4"
	my @T = localtime;					#current date
	my @B = localtime(time()-7*86400);	#date before n*day, a day is 86400

	return "&from_year=".(1900 + $B[5])."&from_month=".(1+$B[4])."&from_day=".$B[3].
		"&until_year=".(1900 + $T[5])."&until_month=".(1+$T[4])."&until_day=".$T[3];
}

### this methods is mapping STOCK TICKERS into ISIN by an internal mapping table
#################################################
sub ticker2isin {
	my $ticker = $_[0];
	my $ua = $_[1];
	
	my %iinfo;
	my $isin;
	my ($te, $ts, $row);
	my @rows;
	
	#print "[debug]: ticker2isin(): ticker=", $ticker, "\n";
	
	#$BET_ISINURL
	my $url = $BET_ISINURL."?isinquery=".$ticker;
	#print "[debug]: ticker2isin(): url=", $url, "\n";
	my $response = $ua->request(GET $url);
	#print "[debug]: ", $response->content, "\n";
	if (!$response->is_success) {
		print STDERR  "[debug] ticker2isin(): isin url cannot be read.\n";
       $iinfo{$ticker, "success"} = 0;
       $iinfo{$ticker, "errormsg"} = "Error contacting isin URL";
       next;
   }

	#PARSING
	$te = HTML::TableExtract->new( depth => 9, count => 0 );
	$te->parse(decode_utf8($response->content));
	
	unless ($te->first_table_found()) {
		print STDERR  "[debug] ticker2isin(): no tables on this page\n";
		$iinfo{$ticker, "success"}  = 0;
		$iinfo{$ticker, "errormsg"} = "Parse error";
		return;
	}
	
	# Debug to dump all tables in HTML...
   #print "\n \n \n \n[debug]: ++++ ==== ++++ ==== ++++ ==== ++++ ==== START OF TABLE DUMP ++++  ==== \n \n \n \n";
	#foreach $ts ($te->table_states) {;
	#	printf "\n \n \n \n[debug]: //// //// \\\\ START OF TABLE %d,%d //// \\\\ //// \\\\ \n \n \n \n",$ts->depth, $ts->count;
   #	foreach $row ($ts->rows) {
	#		print "[debug]: ", $row->[0], " | ", $row->[1], " | ", $row->[2], " | ", $row->[3], "\n";
	#		#print "[debug]: ", $row->[0], "\n";
   #	}
   #}
   #print "\n \n \n \n[debug]: ++++ ==== ++++ ==== ++++ ==== ++++ ==== END OF TABLE DUMP ++++ ==== \n \n \n \n";
	
	my $status = 1;
	foreach $ts ($te->tables) {
		#my $cell_ticker = $ts->rows->[4][1];
		#my $cell_isin = $ts->rows->[4][2];
		

		foreach $row ($ts->rows) {
			my $cell_ticker = uc trim($row->[1]);
			my $cell_isin = uc trim($row->[2]);
			#print "[debug]: ", $cell_ticker, " | ", $cell_isin, "\n";
			
			if ($cell_ticker eq uc $ticker) {
				#print "[debug]: found ISIN: ",$cell_isin," for ticker: ", $cell_ticker, "\n";
				foreach (split(/\n/,$cell_isin)) {
					my $line = trim($_);
					#if ($line ne "") { print " [debug]: ticker2isin(): myline ::",$line,"::\n"; }
					if ($line eq "") { $status=0; }
					
					$isin=$line;
					#print " [debug]: ticker2isin(): isin ::",$isin,"::\n";
				}
			}
			
		}
	}
	
	if (!$isin) { 
		#print "[debug]: ticker2isin(): no isin found for ticker: $ticker \n"; 
		$isin=$ticker; 
	} else {
		$iinfo{$ticker, "success"} = $status;
		$iinfo{$ticker, "isin"} = $isin;
	}
	
	
	return wantarray() ? %iinfo : \%iinfo;
}

### this map is used by next method ticker2isin_by_map
### @deprecated
############################
my %ISINS = (
	"AAA", "NL0006033375",
	"ANY", "HU0000079835",
	"BIF", "HU0000074083",
	"BOOK", "HU0000065008",
	"CSEPEL", "HU0000085618",
	"DANUBIUS", "HU0000074067",
	"ECONET", "HU0000058987",
	"EGIS", "HU0000053947",
	"EHEP", "HU0000067582",
	"ELMU", "HU0000074513",
	"EMASZ", "HU0000074539",
	"FEVITAN", "HU0000071972",
	"FHB", "HU0000078175",		
	"FORRAS/T", "HU0000066071",
	"FORRAS/OE", "HU0000066394",
	"FOTEX", "HU0000075189",
	"FREESOFT", "HU0000071030",
	"GENESIS", "HU0000071865",
	"GSPARK", "HU0000083696",
	"HUMET", "HU0000073176",
	"KPACK", "HU0000075692",
	"KONZUM", "HU0000072939",
	"LINAMAR", "HU0000074851",
	"MTELEKOM", "HU0000073507",
	"MOL", "HU0000068952",
	"ORC", "LU0122624777",
	"OTP", "HU0000061726",
	"PANNERGY", "HU0000089867",
	"PFLAX", "HU0000075296",
	"PVALTO", "HU0000072434",
	"PANNUNION", "HU0000092960",
	"PHYLAXIA", "HU0000088414",
	"QUAESTOR", "HU0000074000",
	"RABA", "HU0000073457",
	"RFV", "HU0000086640",
	"RICHTER", "HU0000067624",
	"SYNERGON", "HU0000069950",
	"TVK", "HU0000073119",
	"TVNETWORK", "HU0000072715",
	"ZWACK", "HU0000074844");
	
### this methods is mapping STOCK TICKERS into ISIN by an internal mapping table
### @deprecated by the ticker2isin which is fetching ISIN from BET.HU
#################################################
sub ticker2isin_by_map {
	my $ticker = $_[0];
	my $isin; 
	#print "[debug]: ticker2isin(): ticker=", $ticker, "\n";

	$isin = $ISINS{uc $ticker};
	#print "[debug]: ticker2isin(): isin=", $isin, "\n";
	
	if (!$isin) { 
		#print "[debug]: ticker2isin(): NE\n"; 
		$isin=$ticker; 
	}
	
	return $isin;
}

sub trim {
	my $str = $_[0];
	if ($str) {
		$str =~ s/^\s+//;
		$str =~ s/\s+$//; 
	}
	return $str;
}

1;

=head1 NAME

Finance::Quote::HU - Obtain Hungarian Securities from
www.magyartokepiac.hu
www.bamosz.hu

=head1 SYNOPSIS

   use Finance::Quote;

   $q = Finance::Quote->new;

   # Don't know anything about failover yet...

=head1 DESCRIPTION

This module obtains information about Hungarian Securities. 
Share fetched from www.magyartokepiac.hu, while mutual funds retrieved from www.napi.hu.
Searching is based on ISIN codes, but for main shares it is mapping the ticker-codes to ISIN.

=head1 LABELS RETURNED

Information available from magyartokepiac may include the following labels:

method source name symbol currency date time last price low high open close pe pse cap volume avg_vol

=head1 SEE ALSO

Magyartokepiac website - http://www.magyartokepiac.hu/
Napi Gazdasag website - http://www.bamosz.hu/

Finance::Quote

=cut
