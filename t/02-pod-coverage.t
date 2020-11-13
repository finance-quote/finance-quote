#!/usr/bin/perl -w
use strict;

use Test::More;
use Test::Pod::Coverage 1.00;

if (not $ENV{TEST_AUTHOR}) {
    plan( skip_all => 'Author test.  Set $ENV{TEST_AUTHOR} to true to run.');
}

plan tests => 1;

pod_coverage_ok("Finance::Quote");
