#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 6;

my $q      = Finance::Quote->new();
my $year   = (localtime())[5] + 1900;
my $lastyear = $year - 1;

# my %quotes = $q->morningstaruk("GB0031835118","GB0030880032","BOGUS");
my %quotes = $q->morningstaruk("GB00B61M9437","GB00B8H99P30","BOGUS");
ok(%quotes);

### quotes : %quotes

# Check the last values are defined.  These are the most
#  used and most reliable indicators of success.
ok($quotes{"GB00B61M9437","last"} > 0);
ok($quotes{"GB00B61M9437","success"});

ok($quotes{"GB00B8H99P30","last"} > 0);
ok($quotes{"GB00B8H99P30","success"});

# Check that bogus stocks return failure:

ok(! $quotes{"BOGUS","success"});
