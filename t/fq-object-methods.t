#!/usr/bin/perl -w
use strict;
use Test::More;

plan tests => 11;

use Finance::Quote;
ok(1, "Finance::Quote loaded");

my $q = Finance::Quote->new('YahooJSON');
ok( $q, "specific module constructor");
my $result = $q->fetch("yahoo_json", "IBM");
ok( ref $result eq "HASH" and exists $result->{success}, "check fetch on specific module");
$result = $q->fetch("usa", "IBM");
ok( !defined $result, "check fetch on wrong specific module");

$q = Finance::Quote->new();
ok( $q, "bare constructor");
$result = $q->fetch("usa", "IBM");
ok( ref $result eq "HASH" and exists $result->{success}, "check fetch on specific module");

ok( $q->B_to_billions("1.234B") eq "1234000000", "B_to_billions check");
ok( $q->decimal_shiftup("6.789", 2) eq "678.9", "decimal_shiftup test");

$q = Finance::Quote->new();
ok( $q->get_failover(), "check default failover");
$q->set_failover(0);
ok( !$q->get_failover(), "check set/get failover");

$q = Finance::Quote->new(failover => 0);
ok( !$q->get_failover(), "check failover for named argument constructor");


