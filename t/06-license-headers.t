#!/usr/bin/perl -w
#
# Author test: enforce that every module carries a modern license header.
#
# This guards the cleanup done to modernize the project's GPL notices:
#   * every module must state a license grant (GPL, or "same terms as Perl");
#   * no module may carry the obsolete Free Software Foundation postal
#     address (the FSF now asks projects to point at the licenses URL);
#   * the "if not, see ..." pointer must use the canonical https URL.
#
# Set $ENV{TEST_AUTHOR} to a true value to run.

use strict;
use warnings;
use Test::More;
use File::Find;

if (not $ENV{TEST_AUTHOR}) {
    plan(skip_all => 'Author test.  Set $ENV{TEST_AUTHOR} to true to run.');
}

my @modules;
find(
    sub { push @modules, $File::Find::name if /\.pm\z/ },
    'lib',
);

@modules = sort @modules;
plan tests => scalar(@modules) * 4;

# Obsolete postal addresses that should never reappear in a header.
my @stale_address = (
    qr/Temple Place/,
    qr/Franklin Street|Franklin St\b/,
    qr/02110-1301/,
    qr/02111-1307/,
    qr/write\s+to\s+the\s+Free\s+Software/,
);

for my $file (@modules) {
    open my $fh, '<', $file or die "Cannot read $file: $!";
    my $text = do { local $/; <$fh> };
    close $fh;

    # 1. Must declare a license grant.
    ok(
        $text =~ /GNU General Public License/ || $text =~ /same terms as Perl/i,
        "$file declares a license grant",
    );

    # 2. No obsolete FSF postal address / "write to" language.
    my $stale = '';
    for my $re (@stale_address) {
        if ($text =~ $re) { $stale = "$re"; last; }
    }
    is($stale, '', "$file has no obsolete FSF postal address");

    # 3. No insecure gnu.org/licenses URL.
    unlike(
        $text,
        qr{http://www\.gnu\.org/licenses},
        "$file uses https for the gnu.org/licenses pointer",
    );

    # 4. If it carries the GPL boilerplate, it must use the modern pointer.
    if ($text =~ /You should have received a copy of the GNU General Public License/) {
        like(
            $text,
            qr{see <https://www\.gnu\.org/licenses/>},
            "$file uses the modern 'see <https://www.gnu.org/licenses/>' pointer",
        );
    }
    else {
        pass("$file has no GPL boilerplate requiring a pointer");
    }
}
