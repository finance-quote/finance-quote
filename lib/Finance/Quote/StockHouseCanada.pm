#!/usr/bin/perl -w

#  StockHouseCanada.pm
#
#  author: Chris Carton (ctcarton@gmail.com)
#  
#  Basic outline of this module was copied 
#  from Cdnfundlibrary.pm
#   
#  Version 0.1 Initial version 


package Finance::Quote::StockHouseCanada;
require 5.004;

use strict;

use vars qw($VERSION $STOCKHOUSE_URL $STOCKHOUSE_MAIN_URL);

use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;

$VERSION = '0.1';

$STOCKHOUSE_URL="http://www.stockhouse.ca/fund/index.asp?lang=EN&item=searchresult&by=symbol&searchtext=";
$STOCKHOUSE_MAIN_URL=("http://www.stockhouse.ca");

# FIXME - Add methods to lookup other commodities

sub methods { return (stockhousecanada_fund => \&stockhouse_fund, 
		      canadamutual => \&stockhouse_fund); }

{
    my @labels = qw/currency last date isodate price source/;
    sub labels { return (stockhousecanada_fund => \@labels,
			 canadamutual => \@labels); }
}

#
# =======================================================================

sub stockhouse_fund  {
    my $quoter = shift;
    my @symbols = @_;

    return unless @symbols;

    my %fundquote;

    my $ua = $quoter->user_agent;
	
    foreach (@symbols) {
		
		my $mutual = $_;
		my $url = $STOCKHOUSE_URL.$mutual;
		my $reply = $ua->request(GET $url);
		# print "Retrieving $url\n";

		$fundquote {$mutual, "success"} = 0;

		next unless ($reply->is_success);

		# print $reply->content;

		# Parse out the complete fund name.

		# debug
#		my $te2= new HTML::TableExtract(depth => 1);
#		$te2->parse($reply->content);
#		foreach my $ts ($te2->table_states) {
#		    print "\n***\n*** Table (", join(',', $ts->coords), "):\n***\n";
#		    foreach my $row ($ts->rows) {
#			print join(',', @$row), "\n";
#		    }
#		}

		# Search all tables of depth 1 looking for the fund name.
		my $te= new HTML::TableExtract( depth => 1 );
		$te->parse($reply->content);
		unless ( $te->tables)
		{
			$fundquote {$mutual,"success"} = 0;
			$fundquote {$mutual,"errormsg"} = "Fund name $mutual not found";
			next;
		}

		unless ($te->rows)
		{
			$fundquote {$mutual,"success"} = 0;
			$fundquote {$mutual,"errormsg"} = "Error parsing fund name";
			next;
		}

		foreach my $ts ($te->table_states) {
			my ($a) = ($ts->rows);
			next unless defined $$a[0];
			$$a[0] =~ s/.([A-Za-z0-9() ]+).*/$1/;
			next unless defined $1;
			$fundquote {$mutual, "name"} = $1;
			last;
		}

		# Parse out the rest of the fund data.
		
		$te = HTML::TableExtract->new( headers => ["Quick Stats"],
						  slice_columns => 0 );

		if (!$te) {
			$fundquote {$mutual, "success"} = 0;
			$fundquote {$mutual,"errormsg"} = "Error parsing fund data";
			next;
		}

		$te->parse($reply->content);
		
		my ($ts) = $te->table_states;
		if (!$ts) {
			$fundquote {$mutual, "success"} = 0;
			$fundquote {$mutual,"errormsg"} = "Error parsing fund data";
			next;
		}

		my($a, $b, $c, $d) = $ts->rows;

		$$a[1] =~ s/.(.*)./$1/g; # remove some nbsp characters
		$$d[4] =~ s/.(.*)./$1/g;

		$fundquote {$mutual, "last"} = $$a[1];
		$fundquote {$mutual, "price"} = $$a[1];
		$fundquote {$mutual, "currency"} = $$d[4];

		# Can't find the date anywhere in the returned info so
		# we'll use the current date
		$quoter->store_date(\%fundquote, $mutual, {today => 1});

		$fundquote {$mutual, "symbol"} = $mutual;

		$fundquote {$mutual, "source"} = $STOCKHOUSE_MAIN_URL;

		$fundquote {$mutual, "success"} = 1;
	}

	return %fundquote if wantarray;
	return \%fundquote;

}

1;

