use strict;
use warnings;
use Test::More tests => 6;
use Finance::Quote;

my $quoter = Finance::Quote->new('CMBChina');

# 获取产品数据并验证是否成功
my %info = $quoter->fetch('cmbchina', 'XY040208');
ok($info{'success'}, "Product data fetched successfully");

if ($info{'success'}) {
    # 数据存在时进行诊断输出
    diag("Successfully fetched data for XY040208");
    diag("Net value: " . $info{'last'});
    diag("Date: " . $info{'isodate'});
    
    # 检查必需的字段
    ok(exists $info{$_}, "Field $_ exists") foreach qw/symbol last isodate currency/;
} else {
    # 数据未成功获取时标记相关测试为失败
    fail("Required fields check skipped due to previous failure") foreach qw/1..4/;
}

# 测试无效产品代码的情况
%info = $quoter->fetch('cmbchina', 'INVALID');
ok(!$info{'success'}, "Test with invalid product code");

# 检查货币信息
if ($info{'success'}) {
    is($info{'currency'}, 'CNY', "Currency should be CNY");
} else {
    fail("Currency check skipped due to previous failure");
}
