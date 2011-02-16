#!/usr/bin/perl -w
use strict;
use Finance::Quote::Yahoo::Base;
use Test::More;

plan tests => 18;

#------------------------------------------------------------------------------
# _decimal_shiftup()

is(Finance::Quote::Yahoo::Base::_decimal_shiftup('1',1),   '10');
is(Finance::Quote::Yahoo::Base::_decimal_shiftup('1',2),   '100');

is(Finance::Quote::Yahoo::Base::_decimal_shiftup('1.',1),   '10');
is(Finance::Quote::Yahoo::Base::_decimal_shiftup('1.',2),   '100');

is(Finance::Quote::Yahoo::Base::_decimal_shiftup('1.5',1), '15');
is(Finance::Quote::Yahoo::Base::_decimal_shiftup('1.5',2), '150');
is(Finance::Quote::Yahoo::Base::_decimal_shiftup('1.5',3), '1500');

is(Finance::Quote::Yahoo::Base::_decimal_shiftup('56',1), '560');
is(Finance::Quote::Yahoo::Base::_decimal_shiftup('56',2), '5600');

is(Finance::Quote::Yahoo::Base::_decimal_shiftup('1.2345678901234',3),
   '1234.5678901234');
is(Finance::Quote::Yahoo::Base::_decimal_shiftup('0.12345678',1),
   '1.2345678');
is(Finance::Quote::Yahoo::Base::_decimal_shiftup('0.00001',1),
   '0.0001');

#------------------------------------------------------------------------------
# _B_to_billions()

is(Finance::Quote::Yahoo::Base::_B_to_billions('1B'),   '1000000000');
is(Finance::Quote::Yahoo::Base::_B_to_billions('1.5B'), '1500000000');
is(Finance::Quote::Yahoo::Base::_B_to_billions('1.23456789876B'), '1234567898.76');

exit 0;
