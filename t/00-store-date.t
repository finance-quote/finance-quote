#!/usr/bin/perl -w

# Test to see if Finance::Quote can at least be loaded and store_date is
# working

use strict;
use Test::More;

plan tests => 19;

use Finance::Quote;
ok(1, "Finance::Quote loaded");

my $quote = Finance::Quote->new();

ok($quote, "quote object created");


# Get Today's date
my ($month, $day, $year2) = (localtime())[4,3,5];
$month++;
my $year4 += $year2 + 1900;	# 2007
my $year4m += $year2 + 1900 - 1;# 2006
$year2 -= 100;			# 05
my $isotoday = sprintf("%04d-%02d-%02d", $year4, $month, $day);
my $ustoday  = sprintf("%02d/%02d/%04d", $month, $day, $year4);

# Test date functions
my %info;
$quote->store_date(\%info, "test", {today => 1});
ok($info{"test","isodate"} eq $isotoday,"test->isodate is today");
ok($info{"test","date"} eq $ustoday,"test->date is today");

# Test various permutions of an ISO Date as input
%info = ();
$quote->store_date(\%info, "test", {isodate => "2004-12-31"});
ok($info{"test","date"} eq "12/31/2004", "ISO date permutation 1");
%info = ();
$quote->store_date(\%info, "test", {isodate => "2004 Dec 31"});
ok($info{"test","date"} eq "12/31/2004","ISO date permutation 2");
%info = ();
$quote->store_date(\%info, "test", {isodate => "2004 December 31"});
ok($info{"test","date"} eq "12/31/2004","ISO date permutation 3");

# Test various permutions of an US Date as input
%info = ();
$quote->store_date(\%info, "test", {usdate => "12/31/2004"});
ok($info{"test","isodate"} eq "2004-12-31","US date permutation 1");
%info = ();
$quote->store_date(\%info, "test", {usdate => "Dec 31, 2004"});
ok($info{"test","isodate"} eq "2004-12-31","US date permutation 2");
%info = ();
$quote->store_date(\%info, "test", {usdate => "December 31 2004"});
ok($info{"test","isodate"} eq "2004-12-31","US date permutation 3");

# Test various permutions of an European Date as input
%info = ();
$quote->store_date(\%info, "test", {eurodate => "31/12/2004"});
ok($info{"test","isodate"} eq "2004-12-31","EUR date permutation 1" );
%info = ();
$quote->store_date(\%info, "test", {eurodate => "31 December 2004"});
ok($info{"test","isodate"} eq "2004-12-31","EUR date permutation 2");
%info = ();
$quote->store_date(\%info, "test", {eurodate => "31 Dec, 2004"});
ok($info{"test","isodate"} eq "2004-12-31","EUR date permutation 3");

# Try some other permutions.  A recent change to the date handling
# code changes the behavior if a year is not explicitly provided.  Now
# it will look at the month and decide if the date is in the current
# year or is from the previous year.  This code still has to handle
# being executed on 12/31, thus the dual tests for each date.
%info = ();
$quote->store_date(\%info, "test", {day=>"31", month=>"12"});
ok($info{"test","date"} eq "12/31/$year4" ||
   $info{"test","date"} eq "12/31/$year4m","test year 1");
ok($info{"test","isodate"} eq "$year4-12-31" ||
   $info{"test","isodate"} eq "$year4m-12-31","test year 2");
%info = ();
$quote->store_date(\%info, "test", {day=>"31", month=>"December"});
ok($info{"test","date"} eq "12/31/$year4" ||
   $info{"test","date"} eq "12/31/$year4m","test year 3");
ok($info{"test","isodate"} eq "$year4-12-31" ||
   $info{"test","isodate"} eq "$year4m-12-31","test year 4");
%info = ();
$quote->store_date(\%info, "test", {day=>"31", month=>"December", year => $year2});
ok($info{"test","date"} eq "12/31/$year4" ||
   $info{"test","date"} eq "12/31/$year4m","test year 5");
ok($info{"test","isodate"} eq "$year4-12-31" ||
   $info{"test","isodate"} eq "$year4m-12-31","test year 6");
