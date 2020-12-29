#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 25;

# Test Fidelity functions.

my $q      = Finance::Quote->new();
my @funds = qw/FGRIX FNMIX FASGX/;
my $year = (localtime())[5] + 1900;
my $lastyear = $year - 1;

my %quotes = $q->fidelity_direct(@funds);
ok(%quotes);

### quotes : %quotes

# Check that the name and nav are defined for all of the funds.
foreach my $fund (@funds) {
    ok($quotes{$fund,"nav"} > 0);
    ok(length($quotes{$fund,"name"}));
    ok($quotes{$fund,"success"});
    ok($quotes{$fund, "currency"} eq "USD");
    ok(substr($quotes{$fund,"isodate"},0,4) == $year ||
           substr($quotes{$fund,"isodate"},0,4) == $lastyear);
    ok(substr($quotes{$fund,"date"},6,4) == $year ||
           substr($quotes{$fund,"date"},6,4) == $lastyear);
}

# Some funds have yields instead of navs.  Check one of them too.
%quotes = $q->fidelity_direct("FEQTX");
ok(%quotes);
ok(length($quotes{"FEQTX","name"}));
ok($quotes{"FEQTX","yield"} > 0);
ok($quotes{"FEQTX","success"});
ok($quotes{"FEQTX", "currency"} eq "USD");

# Check that a bogus fund returns no-success.
%quotes = $q->fidelity_direct("BOGUS");
ok(! $quotes{"BOGUS","success"});

