#!/usr/bin/perl -w
use strict;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use Module::Load;
use Test::More;
use Finance::Quote;

plan tests => @Finance::Quote::MODULES - 1;

### [<now>] modules: @Finance::Quote::MODULES;

foreach my $name (grep(!/Currencies/, @Finance::Quote::MODULES)) {
	my $modpath = "Finance::Quote::$name";
	load $modpath;

	my %labelhash = $modpath->labels;
	### name: $name
	### LabelHash: %labelhash

	ok( keys(%labelhash) > 0, "check labels exits and returns non-empty hash");
}

