use strict;
use warnings;


# Enable Debug mode
$ENV{DEBUG} = 1;

use Finance::Quote::CMBChina;

use Test::More tests => 7;
use Finance::Quote;

my $quoter = Finance::Quote->new('CMBChina');

# Fetch the fund data and verfiy if it was successful
my %info = $quoter->fetch('cmbchina', 'XY040208');
ok($info{'XY040208', 'success'}, "Product data fetched successfully");

if ($info{'XY040208', 'success'}) {
    # If the data was exist, output the diagnose
    diag("Successfully fetched data for XY040208");
    diag("Net value: " . $info{'XY040208', 'nav'});
    diag("Date: " . $info{'XY040208', 'isodate'});
    
    # check if the required fields exists
    ok(exists $info{'XY040208', $_}, "Field $_ exists") foreach qw/symbol nav isodate currency/;
} else {
    # mark as fail if the data is not fetched.
    fail("Required fields check skipped due to previous failure") foreach qw/1..4/;
}

# test the output for invalid product code
%info = $quoter->fetch('cmbchina', 'INVALID');
ok(!$info{'INVALID', 'success'}, "Test with invalid product code");

SKIP: {
    skip "Data fetch failed, currency check skipped", 1 unless $info{'INVALID', 'success'};
    is($info{'INVALID', 'currency'}, 'CNY', "Currency should be CNY");
}
