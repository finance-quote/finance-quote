#!/usr/bin/perl -w

# A test script to check for working of the BOMSE module.

use strict;
use Test;
use Data::Dumper;
use Finance::Quote;

BEGIN {plan tests => 26};

#Ensure that print statements print in order
autoflush STDOUT 1;

my $q      = Finance::Quote->new();

#List of stocks to fetch. Feel free to change this during testing
my @stocks = ("SUZLON.BO", "RECLTD.NS", "AMZN");


my %quotes = $q->fetch("bomse", @stocks);
print "\nChecking if any data is returned: ";
ok(%quotes);


foreach my $stock (@stocks) 
	{
	
	my $name = $quotes{$stock, "name"};
	print "\n\n#Testing $stock";
	print "\nFetch successful?: ";
	ok($quotes{$stock, "success"});
	if(!$quotes{$stock, "success"})
		{
		my $errmsg = $quotes{$stock, "errormsg"};
		print "Error Message:\n$errmsg\n";
		}
	else
		{
		print "Returned name: $name";
		my $exchange = $quotes{$stock, "exchange"};
		#print "\nCheck Exchange: $exchange ";
		ok($exchange eq 'Sourced from Yahoo Finance (as JSON)');

		my $fetch_method = $quotes{$stock, "method"};
		#print "Fetch Method: $fetch_method ";
		ok($fetch_method eq 'bomse');

		my $last = $quotes{$stock, "last"};
		#print "Last Price: $last ";
		ok($last > 0);

		my $volume = $quotes{$stock, "volume"};
		#print "Volumes: $volume ";
		ok($volume > 0);

		my $currency = $quotes{$stock, "currency"};
		#print "Currency: $currency ";
		ok($currency eq 'INR');

		#TODO: Add a test to raise a warning if the quote is excessively old
		my $isodate = $quotes{$stock, "isodate"};
		print "ISOdate: $isodate ";
		my $date = $quotes{$stock, "date"};
		print "Date: $date ";
		}
	}

print "\nChecking for a bogus stock: ";
# Check that a bogus stock returns no-success.
%quotes = $q->fetch("bomse", "BOGUS");
ok(! $quotes{"BOGUS","success"});
