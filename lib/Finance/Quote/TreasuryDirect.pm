#!/usr/bin/perl -w
#
# TreasuryDirect.pm
#
# vi: set ts=2 sw=2 noai expandtab ic showmode showmatch: 

=begin comment

perl -MData::Dumper -MFinance::Quote -le '$q = Finance::Quote->new(); print Dumper { $q->fetch("treasurydirect", @ARGV) };' 912810QT8 912810QY7

=end comment

=cut

package Finance::Quote::TreasuryDirect;
use strict;
use warnings;


#
# Modification of Rolf Endres' Finance::Quote::ZA
#
# Peter Ratzlaff <pratzlaff@gmail.com>
# April, 2018
#

# VERSION

use vars qw /$VERSION/ ;

use HTTP::CookieJar::LWP;
use HTTP::Request::Common;
use Scalar::Util qw(looks_like_number);
use XML::LibXML;

my $TREASURY_DIRECT_FORM_URL = 'https://www.treasurydirect.gov/GA-FI/FedInvest/selectSecurityPriceDate.htm';
my $TREASURY_DIRECT_URL      = 'https://www.treasurydirect.gov/GA-FI/FedInvest/securityPriceDetail';

our $DISPLAY    = 'TreasuryDirect - US Treasury Bonds';
our @LABELS     = qw/method source symbol rate maturity bid ask eod price date isodate currency/;
our $METHODHASH = {subroutine => \&treasurydirect, 
                   display    => $DISPLAY, 
                   labels     => \@LABELS};

sub methodinfo {
    return ( 
        treasurydirect => $METHODHASH,
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

sub treasurydirect {
  my ($quoter, @symbols) = @_;

  # check for quotes for today, as well as the last three days

  my $time = time();
  my @times = map { $time-86400*$_ } 0..3;

  for my $t (@times) {
    my ($d, $m, $y) = (localtime($t))[3,4,5];
    $y += 1900;
    $m += 1;
    my @quotes = treasurydirect_ymd($y, $m, $d, @_);
    return @quotes if @quotes;
  }

  # Nothing was priced on any of those days. Say so, rather than returning an
  # empty list the caller cannot tell apart from a lookup that never ran.
  my %info;
  for my $symbol (@symbols) {
    $info{$symbol, 'success'}  = 0;
    $info{$symbol, 'errormsg'} = 'No prices published in the last four days';
  }
  return wantarray() ? %info : \%info;
}

sub treasurydirect_ymd {

  my ($y, $m, $d, $quoter, @symbols) = @_;

  return unless @symbols;

  my %info;

  $info{$_, 'success'} = 0 for @symbols;

  # The form is Spring-backed: the POST needs a _csrf token bound to the
  # cookie set when the form is fetched, and answers with a redirect LWP will
  # not follow for POST unless asked.
  my $ua = $quoter->user_agent;
  $ua->cookie_jar(HTTP::CookieJar::LWP->new) unless $ua->cookie_jar;
  $ua->requests_redirectable(['GET', 'HEAD', 'POST']);

  # Bound our own requests when the caller has expressed no preference. The
  # retry loop makes up to eight of them and LWP's default is 180 seconds.
  $ua->timeout(30) unless defined $quoter->get_timeout;

  my $form = $ua->request(GET $TREASURY_DIRECT_FORM_URL);
  unless ($form->is_success) {
    $info{$_, 'errormsg'} = 'Error contacting URL' for @symbols;
    return wantarray() ? %info : \%info;
  }

  # Depends on the form's markup, so name it when it breaks; otherwise the
  # resulting 403 reads as a network fault.
  my ($csrf) = ($form->decoded_content // '') =~ /name="_csrf"\s*value="([^"]+)"/;
  unless (defined $csrf) {
    $info{$_, 'errormsg'} = 'No CSRF token in price form' for @symbols;
    return wantarray() ? %info : \%info;
  }

  my $response = $ua->request(
    POST $TREASURY_DIRECT_URL,
    Referer => $TREASURY_DIRECT_FORM_URL,
    Content => [
      priceDateDay   => $d,
      priceDateMonth => $m,
      priceDateYear  => $y,
      fileType       => 'xml',
      xml            => 'XML FORMAT',
      _csrf          => $csrf,
    ]
  );

  unless ($response->is_success) {
    $info{$_, 'errormsg'} = 'Error contacting URL' for @symbols;
    return wantarray() ? %info : \%info;
  }

  my $bonds = parse_prices($response->decoded_content);
  unless (defined $bonds) {
    $info{$_, 'errormsg'} = 'Parse error' for @symbols;
    return wantarray() ? %info : \%info;
  }

  # A weekend or holiday. The file is only ever for the date asked for, so
  # stepping back is the loop's job, not the server's.
  return unless %{$bonds};

  for my $symbol (@symbols) {

    # GENERAL FIELDS
    $info{$symbol, 'method'} = 'treasurydirect';
    $info{$symbol, 'symbol'} = $symbol;
    $info{$symbol, 'source'} = $TREASURY_DIRECT_FORM_URL;

    # OTHER INFORMATION
    my $bond = $bonds->{uc $symbol};
    unless ($bond) {
      $info{$symbol, 'errormsg'} = 'no match';
      next;
    }

    my $price = price_from($bond);
    unless (defined $price) {
      $info{$symbol, 'errormsg'} = 'no usable price';
      next;
    }

    $info{$symbol, 'success'}  = 1;
    $info{$symbol, 'currency'} = 'USD';
    $info{$symbol, 'price'}    = $price;

    # Publish only what was quoted: fields are strings and may be blank, and
    # EODPrice is zero until after the close.
    $info{$symbol, 'maturity'} = $bond->{maturity}
      if length($bond->{maturity} // '');
    $info{$symbol, $_} = $bond->{$_}
      for grep { looks_like_number($bond->{$_}) and $bond->{$_} > 0 } qw/bid ask eod/;

    # Rate is a decimal fraction here; callers have always had a percentage.
    $info{$symbol, 'rate'} = sprintf("%.3f%%", $bond->{rate} * 100)
      if looks_like_number($bond->{rate});

    $quoter->store_date(\%info, $symbol, {year => $y, month => $m, day => $d});
  }

  return wantarray() ? %info : \%info;
}

# CUSIP => {rate, maturity, bid, ask, eod}. undef if the document will not
# parse; empty hashref for a day with no prices. Separate so it can be tested
# without a network round trip.
sub parse_prices {
  my $xml = shift;

  my $dom = eval { XML::LibXML->load_xml(string => $xml) };
  return unless $dom;

  my %bonds;
  for my $security ($dom->getElementsByLocalName('Security')) {
    my %field;
    for my $child ($security->nonBlankChildNodes()) {
      # nonBlankChildNodes filters whitespace, not comments, and localname is
      # undef on those.
      next unless $child->nodeType == XML_ELEMENT_NODE;
      $field{$child->localname} = $child->textContent;
    }

    my $cusip = $field{Cusip};
    next unless defined $cusip and length $cusip;

    # BUY is what an investor pays, so it is the ask; SELL is what they
    # receive, so it is the bid. BuyPrice is never below SellPrice, and the
    # reverse mapping gives a negative spread.
    $bonds{uc $cusip} = {
                         rate     => $field{Rate},
                         maturity => $field{MaturityDate},
                         ask      => $field{BuyPrice},
                         bid      => $field{SellPrice},
                         eod      => $field{EODPrice},
                         };
  }

  return \%bonds;
}

# The price for one security, or undef if the file quoted nothing usable.
sub price_from {
  my $bond = shift;

  # Schema-required but string-typed, so present without being numeric -
  # CallDate is empty in every record.
  my %num = map { $_ => looks_like_number($bond->{$_}) ? $bond->{$_} + 0 : 0 }
            qw/bid ask eod/;

  # A security may be quoted on one side only, and averaging the quoted side
  # against a zero halves it. EODPrice is zero until after the close, so it
  # cannot carry the fallback alone.
  my $price = ($num{bid} > 0 and $num{ask} > 0) ? 0.5*($num{bid} + $num{ask})
            : $num{eod} > 0                     ? $num{eod}
            : $num{bid} > 0                     ? $num{bid}
            : $num{ask} > 0                     ? $num{ask}
            :                                     undef;

  return defined $price ? sprintf("%.6f", $price) : undef;
}

1;

__END__

=head1 NAME

Finance::Quote::TreasuryDirect - Obtain bond quotes from Treasury Direct

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = $q->fetch('treasurydirect', '912810QT8');

=head1 DESCRIPTION

This module obtains individual bond quotes by CUSIP number from
treasurydirect.gov

Prices come from the XML form of the FedInvest daily price file. Only
securities in that file are available, which is to say marketable Treasury
bills, notes and bonds. Agency, municipal and corporate CUSIPs are not in that
file and return an errormsg of 'no match'.

Prices are quoted per 100 of face value.

=head1 LABELS RETURNED

Information available from Treasury Direct may include the following labels:

method source symbol rate maturity bid ask eod price date isodate currency

C<bid> is the file's SELL column, what an investor receives, and C<ask> is its
BUY column, what an investor pays.

Only the prices the file actually quoted are returned. Some securities,
mostly bills, are quoted on one side only, and the unquoted label is then
absent rather than zero. C<eod> is published after the close, so it is absent
from a file fetched during the trading day.

C<price> is the mean of the bid and the ask where both are quoted, and
otherwise whichever of the end of day price, the bid or the ask is available,
in that order. For a one-sided security that makes the price depend on which
day the fetch lands on - the quoted side from a day in progress, the close
from a completed one - a difference of about a cent.

C<rate> is the coupon as a percentage. Bills are discount instruments and
carry no coupon, so theirs is 0.000%.

=head1 SEE ALSO

treasurydirect.gov

Finance::Quote

=cut
