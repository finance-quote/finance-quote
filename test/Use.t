#!/usr/bin/perl -w

# Test to see if Finance::Quote can at least be loaded and used.
# This file gets a capital name so it will be run before any other
# test.

use strict;
use Test;
BEGIN {plan tests => 19};

use Finance::Quote;
ok(1);			# Yup.  It loaded okay.  Good.  :)

my $quote = Finance::Quote->new();

ok($quote);	# Did we get an object okay?


# Get Today's date
my ($month, $day, $year2) = (localtime())[4,3,5];
$month++;
my $year4 += $year2 + 1900;	# 2005
$year2 -= 100;			# 05
my $isotoday = sprintf("%04d-%02d-%02d", $year4, $month, $day);
my $ustoday  = sprintf("%02d/%02d/%04d", $month, $day, $year4);

# Test date functions
my %info;
$quote->store_date(\%info, "test", {today => 1});
ok($info{"test","isodate"} eq $isotoday);
ok($info{"test","date"} eq $ustoday);

# Test various permutions of an ISO Date as input
%info = ();
$quote->store_date(\%info, "test", {isodate => "2004-12-31"});
ok($info{"test","date"} eq "12/31/2004");
%info = ();
$quote->store_date(\%info, "test", {isodate => "2004 Dec 31"});
ok($info{"test","date"} eq "12/31/2004");
%info = ();
$quote->store_date(\%info, "test", {isodate => "2004 December 31"});
ok($info{"test","date"} eq "12/31/2004");

# Test various permutions of an US Date as input
%info = ();
$quote->store_date(\%info, "test", {usdate => "12/31/2004"});
ok($info{"test","isodate"} eq "2004-12-31");
%info = ();
$quote->store_date(\%info, "test", {usdate => "Dec 31, 2004"});
ok($info{"test","isodate"} eq "2004-12-31");
%info = ();
$quote->store_date(\%info, "test", {usdate => "December 31 2004"});
ok($info{"test","isodate"} eq "2004-12-31");

# Test various permutions of an European Date as input
%info = ();
$quote->store_date(\%info, "test", {eurodate => "31/12/2004"});
ok($info{"test","isodate"} eq "2004-12-31");
%info = ();
$quote->store_date(\%info, "test", {eurodate => "31 December 2004"});
ok($info{"test","isodate"} eq "2004-12-31");
%info = ();
$quote->store_date(\%info, "test", {eurodate => "31 Dec, 2004"});
ok($info{"test","isodate"} eq "2004-12-31");

# Try some other permutions
%info = ();
$quote->store_date(\%info, "test", {day=>"31", month=>"12"});
ok($info{"test","date"} eq "12/31/$year4");
ok($info{"test","isodate"} eq "$year4-12-31");
%info = ();
$quote->store_date(\%info, "test", {day=>"31", month=>"December"});
ok($info{"test","date"} eq "12/31/$year4");
ok($info{"test","isodate"} eq "$year4-12-31");
%info = ();
$quote->store_date(\%info, "test", {day=>"31", month=>"December", year => $year2});
ok($info{"test","date"} eq "12/31/$year4");
ok($info{"test","isodate"} eq "$year4-12-31");
