#!/usr/bin/perl -w
#
# HU.pm
#
# Version 0.1 - Download of Hungarian (HU) stocks from www.MAGYARTOKEPIAC.hu
# This version based on ZA.pm module
#
# Zoltan Levardy <zoltan at levardy dot org>
# 2008


package Finance::Quote::HU;
require 5.004;

use strict;
use vars qw /$VERSION/ ;

use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;
use Encode;

$VERSION='1.15';

my %MONTHS = ( 
	"JAN","01","FEB","02","MAR","03","APR","04","MAY","05","JUN","06","JUL","07","AUG","08","SEP","09","OCT","10","NOV","11","DEC","12");
my %XMONTHS = ( 
	"01","JAN","02","FEB","03","MAR","04","APR","05","MAY","06","JUN","07","JUL","08","AUG","09","SEP","10","OCT","11","NOV","12","DEC");
my %ISINS = (
	"AAA", "NL0006033375",
	"ANY", "HU0000079835",
	"BIF", "HU0000088760",
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
	"RFV", "HU0000089198",
	"RICHTER", "HU0000067624",
	"SYNERGON", "HU0000069950",
	"TVK", "HU0000073119",
	"TVNETWORK", "HU0000072715",
	"ZWACK", "HU0000074844");

my $MAGYARTOKEPIAC_MAINURL = ("http://www.magyartokepiac.hu/");
my $MAGYARTOKEPIAC_URL = ($MAGYARTOKEPIAC_MAINURL."cegadatok/reszletek.php");
my $BAMOSZ_MAINURL = ("http://www.bamosz.hu/");
my $BAMOSZ_URL = ($BAMOSZ_MAINURL."adatok/napiadatok/index.ind?do=show");
#print "[debug]: URL=", $MAGYARTOKEPIAC_URL, "\n";
#print "[debug]: URL=", $BAMOSZ_URL, "\n";

sub methods {
    return (hu => \&magyartokepiac, hungary => \&magyartokepiac, bse => \&magyartokepiac, bux => \&magyartokepiac);
}

sub labels {
    my @labels = qw/method source name symbol currency last date isodate high low p_change/;
    return (hu => \@labels, hungary => \@labels, magyartokepiac => \@labels, bse => \@labels, bux => \@labels);
}   

sub magyartokepiac {

	#print "[debug]: hungary()";

    my $quoter = shift;
    my @symbols = @_;
    my %info;
    my ($te, $ts, $row);
    my @rows;
	
	#print "[debug]: hungary() symbols=",@symbols,"\n";
    return unless @symbols;
	
	my $ua = $quoter->user_agent;
	my $isin;

	foreach my $symbol (@symbols) {
		$isin = ticker2isin($symbol);
		#print "[debug]: hungary() ticker=",$symbol,", isin=",$isin,"\n";

		my $url = $MAGYARTOKEPIAC_URL."?isin=".$isin;
	    #print "[debug]: ", $url, "\n";
	    my $response = $ua->request(GET $url);
	    #print "[debug]: ", $response->content, "\n";
		
		if (!$response->is_success) {
            $info{$symbol, "success"} = 0;
            $info{$symbol, "errormsg"} = "Error contacting URL";
            next;
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
					$info{$symbol, "name"}  = $line;
					
					if (!$line) {
						#print "[debug]: name is empty!\n";
						$status = 0;
						$info{$symbol, "errormsg"} = "The provided ISIN/TICKER is invalid. Your symbol was '$symbol'.";
					}
				}
				if ($status && $c == 6) { #6th "last"
					$price = $line;
					$info{$symbol, "last"}  = $price;
					$info{$symbol, "price"}  = $price;
					#$info{$symbol, "nav"}  = $line;
				}
				if ($status && $c == 7) { #7th "net" ("p_change")
					my @values = split('\s\(.?\s', $line);
					#print "[debug]: line=",$line,"\n";
					#print "[debug]: v[0]=",$values[0],"\n";
					$info{$symbol, "net"}  = $values[0];
					#print "[debug]: v[1]=",$values[1],"\n";
					$values[1] =~ s/\s%\)//;
					#print "[debug]: v[1]=",$values[1],"\n";
					$info{$symbol, "p_change"}  = $values[1];
				}
				if ($status && $c == 8) { #7th "date" "time"
					my @values = split('\s', $line);
					#$info{$symbol, "date"}  = $MONTHS{uc $values[1]}."/".$values[0]."/".substr($values[2],2);
					$info{$symbol, "time"}  = $values[3];

					$quoter->store_date(\%info, $symbol, {eurodate => $line});
					
					#my @values = split('\s', $line);
					#print "SHARE DATE: ",$MONTHS{uc $values[1]}."/".$values[0]."/".substr($values[2],2)." ".$values[3],"\n";
					#print "SHARE DATE: '",$line,"'\n";
				}
				if ($status && $c == 13) { #13th "open"
					$info{$symbol, "open"}  = $line;
				}
				if ($status && $c == 15) { #15th "volume"
					$info{$symbol, "volume"}  = $line;
				}
				if ($status && $c == 17) { #17th "pe"
					$info{$symbol, "pe"}  = $line;
				}
				if ($status && $c == 20) { #20th "close"
					$close = $line;
					$info{$symbol, "close"}  = $close;
				}
				if ($status && $c == 22) { #22th "avg_vol"
					$info{$symbol, "avg_vol"}  = $line;
				}
				if ($status && $c == 24) { #24th "eps"
					$info{$symbol, "eps"}  = $line;

				}
				if ($status && $c == 27) { #27th "high"
					$info{$symbol, "high"}  = $line;
				}
				if ($status && $c == 34) { #34th "eps"
					$info{$symbol, "low"}  = $line;
				}
				if ($status && $c == 38) { #38th "cap"
					$info{$symbol, "cap"}  = $line;
				}
				
				#if ($line ne "") { print " ==>> ",$line, [debug]"\n"; }
				
			}
			
			#POST PROCESSING (out of trade price is the last closing price):
			if ($price eq 0) {
				$info{$symbol, "price"} = $close;
			}

			#if status is 0, then going to find on another website:
			if ($status) {
				# GENERAL FIELDS
			    $info{$symbol, "method"} = "magyartokepiac";
			    $info{$symbol, "symbol"} = $symbol;
			    $info{$symbol, "currency"} = "HUF";
			    $info{$symbol, "source"} = $MAGYARTOKEPIAC_MAINURL;
			} else {
				#print "[debug] magyartokepiac(): isin=",$isin,"\n";
				my %binfo = bamosz($quoter,$ua,$isin);
				$status = $binfo{$isin,"success"};
				# GENERAL FIELDS
			    $info{$symbol, "method"} = "bamosz";
			    $info{$symbol, "symbol"} = $isin;
			    $info{$symbol, "currency"} = "HUF";
			    $info{$symbol, "source"} = $BAMOSZ_MAINURL;
				#LAST and DATE:
				if ($status) {
					$info{$symbol, "date"} = $binfo{$isin,"date"};
					$info{$symbol, "isodate"} = $binfo{$isin,"isodate"};
					#$info{$symbol, "time"} = $binfo{$isin,"time"};
					$info{$symbol, "last"} = $binfo{$isin,"last"};
					$info{$symbol, "price"} = $binfo{$isin,"last"};
					$info{$symbol, "volume"} = $binfo{$isin,"volume"};
					$info{$symbol, "nav"} = $binfo{$isin,"nav"};
					$info{$symbol, "net"} = $binfo{$isin,"net"};
					$info{$symbol, "p_change"} = $binfo{$isin,"p_change"};
					#print "\n",$binfo{$isin,"last"}," ",$binfo{$isin,"date"},"\n";
				}
			}

			$info{$symbol, "success"} = $status;
			#print "[debug]: status set to ",$status,"\n";
		}
	    
	}

    return wantarray() ? %info : \%info;
}

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

sub ticker2isin {
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
	$str =~ s/^\s+//;
	$str =~ s/\s+$//; 
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


