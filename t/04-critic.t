#!/usr/bin/perl -w
use strict;
use Test::More;
use File::Spec;

if (not $ENV{TEST_AUTHOR}) {
    plan( skip_all => 'Author test.  Set $ENV{TEST_AUTHOR} to true to run.');
}

eval { require Test::Perl::Critic; };

if ($@) {
    plan( skip_all => 'Test::Perl::Critic required for test.');
}

Test::Perl::Critic->import();
all_critic_ok();
