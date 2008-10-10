#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{TEST_AUTHOR}) {
    plan( skip_all => 'Author test.  Set $ENV{TEST_AUTHOR} to true to run.');
}

plan tests => 1;

# F::Q doesn't load all its code until we actually create
# an object.

my $fq = Finance::Quote->new;

# Sometimes Data::Dumper gets left in code by accident.  Make sure
# we haven't done so.

ok(! exists $INC{'Data/Dumper.pm'}, "Data::Dumper should not be loaded");
