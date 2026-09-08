#!/usr/bin/perl -w
#
# BrightStart.pm
#
# vi: set ts=2 sw=2 noai expandtab ic showmode showmatch:

=begin comment

perl -MData::Dumper -MFinance::Quote -le '$q = Finance::Quote->new(); print Dumper { $q->fetch("brightstart", @ARGV) };' "Equity Portfolio"

=end comment

=cut

package Finance::Quote::BrightStart;
use strict;
use warnings;

use vars qw /$VERSION/ ;

use HTTP::Request::Common;

# VERSION

my $BRIGHTSTART_URL = 'https://brightstart.com/investment/price-performance/';

our $DISPLAY    = 'BrightStart - Illinois Bright Start 529';
our @LABELS     = qw/method source symbol name last nav price currency date isodate/;
our $METHODHASH = {subroutine => \&brightstart,
                   display    => $DISPLAY,
                   labels     => \@LABELS};

sub methodinfo {
    return (
        brightstart => $METHODHASH,
    );
}

sub labels {
  my %m = methodinfo();
  return map {$_ => [@{$m{$_}{labels}}] } keys %m;
}

sub methods {
  my %m = methodinfo();
  return map {$_ => $m{$_}{subroutine} } keys %m;
}

# Fold a name to something comparable: the plan and the caller rarely spell a
# portfolio the same way, and the trailing "Portfolio" is often dropped.
sub normalise {
  my $s = lc(shift // '');
  $s =~ s/&/ and /g;
  $s =~ s/\bmkt\b/market/g;
  $s =~ s/\bintl\b/international/g;
  $s =~ s/[^a-z0-9]+/ /g;
  $s =~ s/\s+portfolio\s*$//;
  $s =~ s/^\s+|\s+$//g;
  $s =~ s/\s+/ /g;
  return $s;
}

sub brightstart {
  my ($quoter, @symbols) = @_;

  return unless @symbols;

  my %info;

  $info{$_, 'success'} = 0 for @symbols;

  my $ua = $quoter->user_agent;

  my $response = $ua->request(GET $BRIGHTSTART_URL);
  unless ($response->is_success) {
    $info{$_, 'errormsg'} = 'Error contacting URL' for @symbols;
    return wantarray() ? %info : \%info;
  }

  my $content = $response->decoded_content // '';

  # One request returns every portfolio, whatever was asked for. Each is one
  # table row; bounding the search to the row stops a portfolio with no unit
  # value from taking the next one's, and keeps a name the page splits across
  # two anchors together.
  my (%value, %pubdate, %name);
  for my $row (split /(?=<tr[\s>])/i, $content) {
    my @parts = $row =~ m{class="fundname"[^>]*>\s*([^<]+?)\s*</a>}gs;
    next unless @parts;

    next unless $row =~ m{
          Unit\s+Value\s+as\s+of\s+(?<date>\d{1,2}/\d{1,2}/\d{4})\s*</span>
          \s*\$\s*(?<value>[\d,]+\.\d+)
        }sx;

    my ($fund, $date, $value) = (join(' ', @parts), $+{date}, $+{value});
    $value =~ s/,//g;
    my $key = normalise($fund);
    $value{$key}   = $value;
    $pubdate{$key} = $date;
    $name{$key}    = $fund;
  }

  unless (%value) {
    $info{$_, 'errormsg'} = 'Parse error' for @symbols;
    return wantarray() ? %info : \%info;
  }

  for my $symbol (@symbols) {
    $info{$symbol, 'method'} = 'brightstart';
    $info{$symbol, 'symbol'} = $symbol;
    $info{$symbol, 'source'} = $BRIGHTSTART_URL;

    my $want = normalise($symbol);

    my $key;
    if (exists $value{$want}) {
      $key = $want;
    }
    elsif (exists $value{"$want portfolio"}) {
      $key = "$want portfolio";
    }
    else {
      # Only when it is unambiguous; a guess would price the wrong fund.
      my @hits = grep { index($_, $want) >= 0 or index($want, $_) >= 0 }
                 keys %value;
      $key = $hits[0] if scalar(@hits) == 1;
    }

    unless (defined $key) {
      $info{$symbol, 'errormsg'} = 'no match';
      next;
    }

    $info{$symbol, 'name'}     = $name{$key};
    $info{$symbol, 'last'}     = $value{$key};
    $info{$symbol, 'nav'}      = $value{$key};
    $info{$symbol, 'price'}    = $value{$key};
    $info{$symbol, 'currency'} = 'USD';
    $quoter->store_date(\%info, $symbol, {usdate => $pubdate{$key}});
    $info{$symbol, 'success'}  = 1;
  }

  return wantarray() ? %info : \%info;
}

1;

__END__

=head1 NAME

Finance::Quote::BrightStart - Obtain unit values for Illinois Bright Start 529
portfolios

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = $q->fetch('brightstart', 'Vanguard Total Stock Market Index 529 Portfolio');

=head1 DESCRIPTION

This module obtains daily unit values for the portfolios of the Illinois
Bright Start Direct-Sold College Savings Program, from the plan's public price
and performance page. No account or API key is needed.

Every portfolio is returned by a single request, so asking for many symbols
costs no more than asking for one.

Bright Start portfolios have no ticker, so the symbol is the portfolio's name.
Matching ignores case and punctuation, tolerates a missing trailing
"Portfolio", and accepts a partial name when exactly one portfolio matches, so
"DFA International Small" and "dfa intl small company" both reach the DFA
International Small Company 529 Portfolio. A name matching several portfolios
fails rather than pricing one of them.

The current lineup is listed at

    https://brightstart.com/investment/price-performance/

=head1 LABELS RETURNED

Information available from Bright Start may include the following labels:

method source symbol name last nav price currency date isodate

=head1 SEE ALSO

Illinois Bright Start, https://brightstart.com/

Finance::Quote

=cut
