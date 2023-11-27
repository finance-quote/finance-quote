#!/usr/bin/perl -w
use strict;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 8;

my $year = (localtime())[5] + 1900;
my $lastyear = $year - 1;
my $q      = Finance::Quote->new("Finanzpartner");

my %quotes = $q->finanzpartner("LU0293315023", "BOGUS", "LU0856992614", "LU1720050803");
ok(%quotes);

### quotes : %quotes

# Check that the last and date values are defined.
ok($quotes{"LU0293315023","success"});
ok($quotes{"LU0293315023","last"} > 0);
ok(length($quotes{"LU0293315023","date"}) > 0);
ok(substr($quotes{"LU0293315023","isodate"},0,4) == $year ||
    substr($quotes{"LU0293315023","isodate"},0,4) == $lastyear);
ok(substr($quotes{"LU0293315023","date"},6,4) == $year ||
    substr($quotes{"LU0293315023","date"},6,4) == $lastyear);
ok($quotes{"LU0293315023","currency"} eq "EUR");

ok($quotes{"LU0856992614","success"});
ok($quotes{"LU0856992614","last"} > 0);
ok(length($quotes{"LU0856992614","date"}) > 0);
ok(substr($quotes{"LU0856992614","isodate"},0,4) == $year ||
    substr($quotes{"LU0856992614","isodate"},0,4) == $lastyear);
ok(substr($quotes{"LU0856992614","date"},6,4) == $year ||
    substr($quotes{"LU0856992614","date"},6,4) == $lastyear);
ok($quotes{"LU0856992614","currency"} eq "EUR");

ok($quotes{"LU1720050803","success"});
ok($quotes{"LU1720050803","last"} > 0);
ok(length($quotes{"LU1720050803","date"}) > 0);
ok(substr($quotes{"LU1720050803","isodate"},0,4) == $year ||
    substr($quotes{"LU1720050803","isodate"},0,4) == $lastyear);
ok(substr($quotes{"LU1720050803","date"},6,4) == $year ||
    substr($quotes{"LU1720050803","date"},6,4) == $lastyear);
ok($quotes{"LU1720050803","currency"} eq "USD");

# Check that a bogus fund returns non-success.
ok($quotes{"BOGUS","success"} == 0);
