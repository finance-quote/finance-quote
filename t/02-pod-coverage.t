#!/usr/bin/perl -w
use strict;

use Test::More;

if (not $ENV{TEST_AUTHOR}) {
    plan( skip_all => 'Author test.  Set $ENV{TEST_AUTHOR} to true to run.');
}

eval "use Test::Pod::Coverage 1.00";
plan skip_all => "Test::Pod::Coverage 1.00 required for testing POD" if $@;
all_pod_coverage_ok();
