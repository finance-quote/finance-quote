#!/usr/bin/perl -w
use Test;
use Finance::Quote;
use strict;

BEGIN { plan tests => 3 }

my $q = Finance::Quote->new;
ok($q);

my %quotes = $q->tdefunds("TD Canadian Index");

ok(%quotes);
ok($quotes{"TD Canadian Index", "nav"});
