#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 23};

use Finance::Quote;

# Test AEX functions.

my $quoter = Finance::Quote->new();

my %quotes = $quoter->aex("AAB AEX TL 440");
ok(%quotes);

# Check that some values are defined.
ok($quotes{"AAB AEX TL 440","success"});
ok($quotes{"AAB AEX TL 440","last"} > 0);
ok($quotes{"AAB AEX TL 440","date"});
ok($quotes{"AAB AEX TL 440","volume"} > 0);

my $year = (localtime())[5] + 1900;
ok(substr($quotes{"AAB AEX TL 440","isodate"},0,4) == $year);
ok(substr($quotes{"AAB AEX TL 440","date"},6,4) == $year);

# Exercise the fetch function 
%quotes = $quoter->fetch("aex","AAB AAB TL 19");
ok(%quotes);
ok($quotes{"AAB AAB TL 19","success"});
ok($quotes{"AAB AAB TL 19","last"} > 0);

# Test options fetching
# the following tests will fail after Dec 2009:-(
%quotes = $quoter->fetch("aex_options", "aex c dec 2009 400.00", "phi");
ok(%quotes);

ok($quotes{"aex c dec 2009 400.00","success"});
ok($quotes{"aex c dec 2009 400.00","close"} > 0);
#ok($quotes{"aex c dec 2009 400.00","bid"});	# May or may not exist
#ok($quotes{"aex c dec 2009 400.00","ask"});	# May or may not exist

ok($quotes{"phi","success"});
ok($quotes{"phi","options"});
ok($quotes{ $quotes{"phi","options"}->[0],"close"});
ok($quotes{ $quotes{"phi","options"}->[0],"date"});

# Test futures fetching
%quotes = $quoter->fetch("aex_futures", "fti");
ok(%quotes);

# Check that some values are defined.
ok($quotes{"fti","success"});
ok($quotes{"fti","futures"});
ok($quotes{ $quotes{"fti","futures"}->[0],"last"} > 0);
ok($quotes{ $quotes{"fti","futures"}->[0],"date"});

# Check that a bogus fund returns no-success.
%quotes = $quoter->aex("BOGUS");
ok( ! $quotes{"BOGUS","success"});
