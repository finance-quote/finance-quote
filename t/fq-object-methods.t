#!/usr/bin/perl -w
use strict;
use Test::More;

plan tests => 23;

use Finance::Quote;
ok(1, "Finance::Quote loaded");

my $q = Finance::Quote->new('YahooJSON');
ok( $q, "specific module constructor");
my $result = $q->fetch("yahoo_json", "IBM");
ok( (ref $result eq "HASH" and exists $result->{'IBM','success'}), "check fetch on specific module");
$result = $q->fetch("usa", "IBM");
ok( !defined $result, "check fetch on wrong specific module");

$q = Finance::Quote->new();
ok( $q, "bare constructor");
$result = $q->fetch("usa", "IBM");
ok( (ref $result eq "HASH" and exists $result->{'IBM','success'}), "check fetch on specific module");

ok( $q->B_to_billions("1.234B") eq "1234000000", "B_to_billions check");
ok( $q->decimal_shiftup("6.789", 2) eq "678.9", "decimal_shiftup test");

$q = Finance::Quote->new();
ok( $q->get_failover(), "check default failover");
$q->set_failover(0);
ok( !$q->get_failover(), "check set/get failover");

$q = Finance::Quote->new(failover => 0);
ok( !$q->get_failover(), "check failover for named argument constructor");

$q = Finance::Quote->new();
ok( !defined $q->get_fetch_currency(), "default currency is not defined");
$q->set_fetch_currency('aud');
ok( 'aud' eq $q->get_fetch_currency(), "check set/get currency");

$q = Finance::Quote->new(fetch_currency => 'usd');
ok( 'usd' eq $q->get_fetch_currency(), "check named parameter fetch_currency");

$q = Finance::Quote->new();
ok( 0 == @{$q->get_required_labels()}, "check default required labels");
my $labels = ['close', 'isodate', 'last'];
$q->set_required_labels($labels);
ok( join(",", sort @{$labels}) eq join(",", @{$q->get_required_labels()}), "check set/get required_labels");
$result = $q->fetch("yahoo_json", "IBM");
ok( (ref $result eq "HASH" and exists $result->{'IBM','success'}), "check fetch on specific module");

$q = Finance::Quote->new(required_labels => ['does-not-exist']);
ok( 'does-not-exist' eq join(",", @{$q->get_required_labels()}), "check set/get required_labels");
$result = $q->fetch("usa", "IBM");
ok( (ref $result eq "HASH" and !%{$result}), "check required_labels is enforeced");

$q = Finance::Quote->new();
ok( !defined $q->get_timeout(), "check default timeout");
$q->set_timeout(123);
ok( 123 == $q->get_timeout(), "check set/get timeout");
$q = Finance::Quote->new(timeout => 456);
ok( 456 == $q->get_timeout(), "check timeout as named parameter");

print ref $q->get_user_agent(), "\n";

ok( 'LWP::UserAgent' eq ref $q->get_user_agent(), "check get_user_agent");
