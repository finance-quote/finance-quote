#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 19;

# Test usfedbonds functions.

my $year = (localtime())[5] + 1900;
my $lastyear = $year - 1;
my $q      = Finance::Quote->new("USFedBonds");

#my %quotes = $q->usfedbonds("E197001.200606");
my %quotes = $q->usfedbonds("E197001.200606","E194112.200610","E194101.200610","E194001.200610","BOGUS");
ok(%quotes);

TODO: {
  local $TODO="To be debugged";

  # Check that the last and date values are defined.
  ok($quotes{"E197001.200606","success"});
  ok($quotes{"E197001.200606","price"} > 0);
  ok(length($quotes{"E197001.200606","date"}) > 0);
  ok(substr($quotes{"E197001.200606","isodate"},0,4) eq $year ||
       substr($quotes{"E197001.200606","isodate"},0,4) eq $lastyear);
  ok(substr($quotes{"E197001.200606","date"},6,4) eq $year ||
       substr($quotes{"E197001.200606","date"},6,4) eq $lastyear);
  ok($quotes{"E197001.200606","currency"} eq "USD");

  ok($quotes{"E194112.200610","success"});
  ok($quotes{"E194112.200610","price"} > 0);
  ok(length($quotes{"E194112.200610","date"}) > 0);
  ok(substr($quotes{"E194112.200610","isodate"},0,4) eq $year ||
       substr($quotes{"E194112.200610","isodate"},0,4) eq $lastyear);
  ok(substr($quotes{"E194112.200610","date"},6,4) eq $year ||
       substr($quotes{"E194112.200610","date"},6,4) eq $lastyear);
  ok($quotes{"E194112.200610","currency"} eq "USD");
}

# Check that a non-existent price returns no-success.
ok($quotes{"E194101.200610","success"} == 0);

TODO: {
  local $TODO="To be debugged";
  ok($quotes{"E194101.200610","errormsg"} eq "No value found");
}

# Check that a non-existent price returns no-success.
ok($quotes{"E194001.200610","success"} == 0);

TODO: {
  local $TODO="To be debugged";
  ok($quotes{"E194001.200610","errormsg"} eq "Date not found");
}

# Check that a bogus fund returns no-success.
ok($quotes{"BOGUS","success"} == 0);
ok($quotes{"BOGUS","errormsg"} eq "Parse error");
