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
# Older versions of XML::LibXML is an example.
# Unfortunately for Ubuntu 22.04 and earlier (and likely other Linux
# distributions), the later versions are not available from the standard
# repositories. In addition, attempting to install the current version
# of XML::LibXML from CPAN for those operating systems fails with many
# errors during "make test". Decision was made to use SKIP rather than
# having users run cpan or cpanm with the no test option.

SKIP: {
  skip "XML::LibXML version not > 2.0207",
    1 if ($XML::LibXML::VERSION <= 2.0207);
  ok(! exists $INC{'Data/Dumper.pm'}, "Data::Dumper should not be loaded");
}

