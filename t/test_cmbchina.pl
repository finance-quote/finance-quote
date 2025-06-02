use strict;
use warnings;
use Test::More tests => 4;
use Finance::Quote;

# 创建一个新的Finance::Quote对象
my $quoter = Finance::Quote->new('CMBChina');

# 测试获取招商银行理财产品净值
my %info = $quoter->fetch('cmbchina', 'XY040208');

# 检查是否成功获取数据
ok(exists $info{'XY040208', 'success'}, 'Check if success field exists');
if ($info{'XY040208', 'success'}) {
    diag("Successfully fetched data for XY040208");
    diag("Net value: " . $info{'XY040208', 'last'});
    diag("Date: " . $info{'XY040208', 'isodate'});
} else {
    diag("Failed to fetch data for XY040208: " . $info{'XY040208', 'errormsg'});
}

# 检查返回的数据结构是否包含必要的字段
ok(exists $info{'XY040208', 'last'} && exists $info{'XY040208', 'isodate'}, 'Check for required fields');

# 测试错误情况（使用不存在的产品代码）
my %error_info = $quoter->fetch('cmbchina', 'INVALID_CODE');
ok(exists $error_info{'INVALID_CODE', 'success'} && !$error_info{'INVALID_CODE', 'success'}, 'Test with invalid product code');

# 检查货币信息是否正确
ok(exists $info{'XY040208', 'currency'} && $info{'XY040208', 'currency'} eq 'CNY', 'Check currency information');
