use strict;
use warnings;


# 启用 DEBUG 模式
$ENV{DEBUG} = 1;

use Finance::Quote::CMBChina;

use Test::More tests => 7;
use Finance::Quote;

my $quoter = Finance::Quote->new('CMBChina');

# 获取产品数据并验证是否成功
my %info = $quoter->fetch('cmbchina', 'XY040208');
ok($info{'XY040208', 'success'}, "Product data fetched successfully");

if ($info{'XY040208', 'success'}) {
    # 数据存在时进行诊断输出
    diag("Successfully fetched data for XY040208");
    diag("Net value: " . $info{'XY040208', 'nav'});
    diag("Date: " . $info{'XY040208', 'isodate'});
    
    # 检查必需的字段
    ok(exists $info{'XY040208', $_}, "Field $_ exists") foreach qw/symbol nav isodate currency/;
} else {
    # 数据未成功获取时标记相关测试为失败
    fail("Required fields check skipped due to previous failure") foreach qw/1..4/;
}

# 测试无效产品代码的情况
%info = $quoter->fetch('cmbchina', 'INVALID');
ok(!$info{'INVALID', 'success'}, "Test with invalid product code");

SKIP: {
    skip "Data fetch failed, currency check skipped", 1 unless $info{'INVALID', 'success'};
    is($info{'INVALID', 'currency'}, 'CNY', "Currency should be CNY");
}
