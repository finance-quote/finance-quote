#!/usr/bin/perl -w
use Test;
use Finance::Quote;
use strict;

BEGIN { plan tests => 5 }

my $q = Finance::Quote->new;
ok($q);

my %quotes = $q->tdefunds("TD Canadian Index");

ok(%quotes);
ok($quotes{"TD Canadian Index", "nav"});

my $year = (localtime())[5] + 1900;
ok(substr($quotes{"TD Canadian Index","isodate"},0,4) == $year);
ok(substr($quotes{"TD Canadian Index","date"},6,4) == $year);
