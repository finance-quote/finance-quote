#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

plan tests => 28;

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
ok($q->isoTime("0:59PM") eq "12:59" ) ;
ok($q->isoTime("12:00pm") eq "12:00" ) ;
ok($q->isoTime("12:10pm") eq "12:10" ) ; # yahoo might return 12:XXPM !


# decimal_shiftup()

is($q->decimal_shiftup('1',1),   '10');
is($q->decimal_shiftup('1',2),   '100');

is($q->decimal_shiftup('1.',1),   '10');
is($q->decimal_shiftup('1.',2),   '100');

is($q->decimal_shiftup('1.5',1), '15');
is($q->decimal_shiftup('1.5',2), '150');
is($q->decimal_shiftup('1.5',3), '1500');

is($q->decimal_shiftup('56',1), '560');
is($q->decimal_shiftup('56',2), '5600');

is($q->decimal_shiftup('56.00',-1), '5.600'); # we want to keep precision
is($q->decimal_shiftup('56.00',1), '560.0');

is($q->decimal_shiftup('1.2345678901234',3),
   '1234.5678901234');
is($q->decimal_shiftup('0.12345678',1),
   '1.2345678');
is($q->decimal_shiftup('0.00001',1),
   '0.0001');

# _B_to_billions()

is($q->B_to_billions('1B'),   '1000000000');
is($q->B_to_billions('1.5B'), '1500000000');
is($q->B_to_billions('1.23456789876B'), '1234567898.76');
