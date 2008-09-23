#!/usr/bin/perl -w
use strict;
use Test;
use Data::Dumper;
BEGIN {plan tests => 8};

use Finance::Quote;

# Test ManInvestments functions.

my $q      = Finance::Quote->new();

my %quotes = $q->maninv("OMIP220","BOGUS");
ok(%quotes);

# Check the nav values are defined.  These are the most
#  used and most reliable indicators of success.
ok($quotes{"OMIP220","last"} > 0);
ok(length($quotes{"OMIP220","name"}) > 0);
ok($quotes{"OMIP220","success"});
ok($quotes{"OMIP220", "currency"} eq "AUD");

my $year = (localtime())[5] + 1900;
my $lastyear = $year - 1;
ok((substr($quotes{"OMIP220","isodate"},0,4) == $year) ||
   (substr($quotes{"OMIP220","isodate"},0,4) == $lastyear));
ok((substr($quotes{"OMIP220","date"},6,4) == $year) ||
   (substr($quotes{"OMIP220","date"},6,4) == $lastyear));

# Check that a bogus stock returns no-success.
ok(! $quotes{"BOGUS","success"});
