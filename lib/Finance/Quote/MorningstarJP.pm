#
# Copyright (C) 2024, Przemyslaw Kryger
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# $Id: $
#

package Finance::Quote::MorningstarJP;
use strict;
use warnings;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use XML::LibXML;
use LWP::UserAgent;
use String::Util qw(trim);

# VERSION

our $DISPLAY    = 'Morningstar JP';
our @LABELS     = qw/nav isin symbol name currency date isodate/;
our $METHODHASH = {subroutine => \&morningstarjp,
                   display => $DISPLAY,
                   labels => \@LABELS};

sub methodinfo {
    return (
        morningstarjp => $METHODHASH,
    );
}

sub labels { my %m = methodinfo(); return map {$_ => [@{$m{$_}{labels}}] } keys %m; }

sub methods {
  my %m = methodinfo(); return map {$_ => $m{$_}{subroutine} } keys %m;
}

sub morningstarjp {
    my $quoter  = shift;
    my @symbols = @_;
    my $ua      = $quoter->user_agent();
    my %info;

    foreach my $symbol (@_) {
      eval {
        my $url   = "https://apl.wealthadvisor.jp/webasp/funddataxml/basic/basic_$symbol.xml";
        my $reply = $ua->get($url);

        my $dom;
        eval {$dom = XML::LibXML->load_xml(string => $reply->decoded_content)};
        if ($@) {
          $info{$symbol, 'success' }  = 0;
          $info{$symbol, 'errormsg' } = $@;
          next;
        }
        ### [<now>] DOM: $dom->toString()

        unless ($dom->findnodes('//Fund/@MS_FUND_CODE')->[0]->to_literal() eq $symbol) {
          $info{$symbol, 'success'}  = 0;
          $info{$symbol, 'errormsg'} = 'Symbol not found';
          next;
        }

        my $nav = $dom->findnodes('//Fund/Price/@KIJYUNKAGAKU')->[0]->to_literal();
        $nav =~ s/,//;
        my $date = $dom->findnodes('//Fund/Price/@KIJYUN_YMD')->[0]->to_literal();
        $date =~ s/[^0-9]/-/g;
        my $isin = $dom->findnodes('//Fund/@ISIN')->[0]->to_literal();
        my $name = $dom->findnodes('//Fund/@FUND_NAME')->[0]->to_literal();

        $info{$symbol, 'success'}  = 1;
        $info{$symbol, 'method'}   = 'MorningstarJP';
        $info{$symbol, 'currency'} = 'JPY';
        $info{$symbol, 'symbol'}   = $symbol;
        $info{$symbol, 'nav'}      = $nav;
        $info{$symbol, 'isin'}     = $isin;
        $info{$symbol, 'name'}     = $name;

        $quoter->store_date(\%info, $symbol, {isodate => $date});
      };

      if ($@) {
        my $error = "Search failed: $@";
        $info{$symbol, 'success'}  = 0;
        $info{$symbol, 'errormsg'} = trim($error);
      }
    }

    ### info : %info

    return wantarray() ? %info : \%info;
}

1;

__END__

=head1 NAME

Finance::Quote::MorninstarJP - Obtain quotes from from Morningstar (Japan)

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %stockinfo = $q->fetch("morningstarjp", "2009100101");

=head1 DESCRIPTION

This module obtains information from Morningstar (Japan),
L<http://www.wealthadvisor.co.jp/>.

Information returned by this module is governed by Morningstar
(Japan)'s terms and conditions.

=head1 FUND SYMBOLS

Use the numeric symbol shown in the URL on the "SnapShot" page
of the security of interest.

e.g. For L<https://www.wealthadvisor.co.jp/snapshot/2009100101>,
one would supply 2009100101 as the symbol argument on the fetch API call.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::MorningstarJP:
nav, isin, symbol, name, currency.

=head1 Terms & Conditions

Use of apl.wealthadvisor.jp is governed by any terms & conditions of that site.

Finance::Quote is released under the GNU General Public License, version 2,
which explicitly carries a "No Warranty" clause.

=head1 SEE ALSO

Morningstar (Japan), L<http://www.wealthadvisor.co.jp/>

=cut
