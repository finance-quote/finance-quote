#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

plan tests => 8;

my $q      = Finance::Quote->new();

# test isoTime function
ok($q->isoTime("11:39PM") eq "23:39") ;
ok($q->isoTime("9:10 AM") eq "09:10") ;
ok($q->isoTime("1.32") eq "01:32") ;
ok($q->isoTime("1u32") eq "01:32") ;
ok($q->isoTime("19h2") eq "19:02") ;
ok($q->isoTime("10:62") eq "00:00" ) ;
ok($q->isoTime("8:05am") eq "08:05" ) ;
ok($q->isoTime("4:00pm") eq "16:00" ) ;
