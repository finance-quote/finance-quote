#!/usr/bin/perl -w
# vi: set ts=4 sw=4 noai ic showmode showmatch:

#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
#    02110-1301, USA

package Finance::Quote::Toushin;

use strict;
use warnings;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use Encode;
use JSON qw(decode_json);
use LWP::UserAgent;
use List::Util qw(reduce);
use Web::Scraper;

# VERSION

our $DISPLAY    = 'The Investment Trusts Association, Japan';
our @LABELS     = qw/last nav isin name currency date isodate/;
our $METHODHASH = {subroutine => \&toushin,
                   display => $DISPLAY,
                   labels => \@LABELS};

sub methodinfo {
    return (
        toushin => $METHODHASH,
    );
}

sub labels { my %m = methodinfo(); return map {$_ => [@{$m{$_}{labels}}] } keys %m; }

sub methods {
  my %m = methodinfo(); return map {$_ => $m{$_}{subroutine} } keys %m;
}

sub toushin {
    my $quoter  = shift;
    my @symbols = @_;
    my $ua      = $quoter->user_agent();
    my %info;

    foreach my $symbol (@_) {
      eval {
        my $html_url   = "https://toushin-lib.fwg.ne.jp/FdsWeb/FDST030000?isinCd=$symbol";
        my $html_reply = $ua->get($html_url);

        # Follow what the original script does, and just get value attribute of
        # object with id associFundCd, see
        # https://toushin-lib.fwg.ne.jp/static/js/web/FDST0300/FDST030000.js?v=20240927-220554 does,
        my $scraper = scraper {
            process '//*[contains(@id, "associFundCd")]', "associ_fund_cd" => '@value';
            process "title", "name" => "TEXT";
        };

        my $scraped = $scraper->scrape($html_reply->decoded_content);
        ### [<now>] scraped: $scraped

        # Alternative data source:
        # curl 'https://toushin-lib.fwg.ne.jp/FdsWeb/FDST030000/get-basis-price-chart-date' \
        #       --data 'termFlg=1&associFundCd=5131109A&separateseparateDiv=0'
        # where:
        #   termFlg is length in months, 1 should be sufficient
        #   separateseparateDiv can be scrapped from web page just like associFundCd

        my $json_url   = "https://toushin-lib.fwg.ne.jp/FdsWeb/FDST030000/show-recent-price-date";

        my $json_reply = $ua->post($json_url,
                                   Content => [
                                       "isinCd" => $symbol,
                                       "associFundCd" => $scraped->{asoci_fund_cd}
                                   ]);
        ### [<now>] json_reply: $json_reply

        my $json = decode_json($json_reply->decoded_content);

        my $datum = reduce { @$a[0] gt @$b[0] ? $a : $b } @$json;

        ### [<now>] datum: $datum

        my ($day, $month, $year) = split /\//, @$datum[0];
        $quoter->store_date(\%info, $symbol,
                            {day => $day, month => $month, year => $year});

        $info{$symbol, 'success'}  = 1;
        $info{$symbol, 'currency'} = 'JPY';
        $info{$symbol, 'symbol'}   = $symbol;
        $info{$symbol, 'last'}     = @$datum[1];
        $info{$symbol, 'nav'}      = @$datum[1]; # Google translates 基準価額 (which is description of this value in the page) to NAV
        $info{$symbol, 'isin'}     = $symbol;
        $info{$symbol, 'name'}     = encode("utf8", $scraped->{name});

      }
    }

    ### info : %info

    return wantarray() ? %info : \%info;
}

1;

__END__

=head1 NAME

Finance::Quote::Toushin - Obtain quotes from The Investment Trusts Association, Japan

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %stockinfo = $q->fetch('toushin','JP90C0006HN6');

=head1 DESCRIPTION

This module obtains information from L<The Investment Trusts Association, Japan|https://www.toushin.or.jp/>.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::Toushin:
last, nav, isin, name, currency, date, isodate

=head1 Terms & Conditions

Use of nzx.com is governed by any terms & conditions of that site.

Finance::Quote is released under the GNU General Public License, version 2,
which explicitly carries a "No Warranty" clause.

=cut
