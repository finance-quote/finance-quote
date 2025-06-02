use strict;
use warnings;
use Finance::Quote::CMBChina;

# 启用 DEBUG 模式
$ENV{DEBUG} = 1;

# 添加 Finance::Quote 模块的路径到 @INC
use lib 'C:/Users/fatca/Documents/Devs/FQ_CMBChina/finance-quote/lib';  # 替换为你的模块实际安装路径

use Test::More tests => 6;
use Finance::Quote;

my $quoter = Finance::Quote->new('CMBChina');

# 获取产品数据并验证是否成功
my %info = $quoter->fetch('cmbchina', 'XY040208');
ok($info{'XY040208', 'success'}, "Product data fetched successfully");

if ($info{'XY040208', 'success'}) {
    # 数据存在时进行诊断输出
    diag("Successfully fetched data for XY040208");
    diag("Net value: " . $info{'XY040208', 'last'});
    diag("Date: " . $info{'XY040208', 'isodate'});
    
    # 检查必需的字段
    ok(exists $info{'XY040208', $_}, "Field $_ exists") foreach qw/symbol last isodate currency/;
} else {
    # 数据未成功获取时标记相关测试为失败
    fail("Required fields check skipped due to previous failure") foreach qw/1..4/;
}

# 测试无效产品代码的情况
%info = $quoter->fetch('cmbchina', 'INVALID');
ok(!$info{'INVALID', 'success'}, "Test with invalid product code");

# 只有在成功获取数据时才检查货币信息
if ($info{'INVALID', 'success'}) {
    is($info{'INVALID', 'currency'}, 'CNY', "Currency should be CNY");
} else {
    diag("Currency check skipped due to previous failure");
}
