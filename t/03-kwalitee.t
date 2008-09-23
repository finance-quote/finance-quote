#!/usr/bin/perl -w
use strict;

use Test::More;

if (not $ENV{TEST_AUTHOR}) {
    plan( skip_all => 'Author test.  Set $ENV{TEST_AUTHOR} to true to run.');
}

eval { require Test::Kwalitee; Test::Kwalitee->import() };
plan( skip_all => 'Test::Kwalitee not installed; skipping' ) if $@;
