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

use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;
use HTTP::Request;

my $TREASURY_DIRECT_URL = 'https://www.treasurydirect.gov/GA-FI/FedInvest/todaySecurityPriceDate.htm';

our $DISPLAY    = 'TreasuryDirect - US Treasury Bonds';
our @LABELS     = qw/method source symbol rate bid ask price date isodate/;
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

}

sub treasurydirect_ymd {

  my ($y, $m, $d, $quoter, @symbols) = @_;

  return unless @symbols;

  my %info;

  $info{$_, 'success'} = 0 for @symbols;

  my $ua = $quoter->user_agent;
  $ua->timeout(10);
  $ua->ssl_opts( verify_hostname => 0 );

  my $content;
  my $url = $TREASURY_DIRECT_URL;
  #print "[debug]: ", $url, "\n";

  if (0) {
    my $response = $ua->request(GET $url);
    #print "[debug]: ", $response->content, "\n";
    if (!$response->is_success) {
      $info{$_, 'errormsg'} = 'Error contacting URL' for @symbols;
      return wantarray() ? %info : \%info;
    }
    $content = $response->content;
  }

  # this is no longer working, for some reason
  elsif (0) {
    my $url = 'https://www.treasurydirect.gov/GA-FI/FedInvest/selectSecurityPriceDate';
#    my $post_data = [ "priceDate.month" => "4", "priceDate.day" => "13", "priceDate.year" => "2018", "submit" => "Show+Prices" ];
    my $post_data = [ 'priceDate.month' => $m,
		      'priceDate.day' => $d,
		      'priceDate.year' => $y,
		      'submit' => 'Show Prices',
		    ];

    my $request = POST( $url, $post_data);
    my $resp = $ua->request($request);
    if ($resp->is_success) {
      $content = $resp->decoded_content;
      # print "[debug]: ", $content, "\n";
    } else {
      $info{$_, 'errormsg'} = 'Error contacting URL' for @symbols;
      return wantarray() ? %info : \%info;
    }
  }

  else {
    my $url = 'https://www.treasurydirect.gov/GA-FI/FedInvest/selectSecurityPriceDate';
    #my $data= 'priceDate.month=1&priceDate.day=4&priceDate.year=2021&submit=Show+Prices';

    my $data =
      'priceDate.month=' . $m .
      '&priceDate.day=' . $d .
      '&priceDate.year=' . $y .
      '&submit=Show+Prices';

    $content = `wget --no-check-certificate --post-data='$data' $url -O - 2>/dev/null`;
  }

  # submitted a future date
  return if $content =~ /Submitted date must be equal to/;

  # weekends, holidays (doesn't work like this any more)
  return if $content =~ /No data for selected date range/;

  my ($date, $isodate);
  if ($content =~ /Prices For:\s+(\w+)\s+(\d+),\s+(\d+)/) {
    my @months = qw/ Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec /;
    my %months; @months{@months} = 1..12;
    my ($year, $month, $day) = ($3, $months{$1}, $2);
    $date = sprintf "%02d/%02d/%04d", $month, $day, $year;
    $isodate = sprintf "%04d-%02d-%02d", $year, $month, $day;
  }

  my $te = new HTML::TableExtract();
  $te->parse($content);
  # print "[debug]: (parsed HTML)",$te, "\n";

  unless ($te->first_table_found()) {
    #print STDERR  "no tables on this page\n";
    $info{$_, 'errormsg'} = 'Parse error' for @symbols;
    return wantarray() ? %info : \%info;
  }

  # Debug to dump all tables in HTML...

=begin comment

  print "\n \n \n \n[debug]: ++++ ==== ++++ ==== ++++ ==== ++++ ==== START OF TABLE DUMP ++++ ==== ++++ ==== ++++ ==== ++++ ==== \n \n \n \n";

  for my $ts ($te->table_states) {

    printf "\n \n \n \n[debug]: //// \\\\ //// \\\\ //// \\\\ //// \\\\ START OF TABLE %d,%d //// \\\\ //// \\\\ //// \\\\ //// \\\\ \n \n \n \n",
      $ts->depth, $ts->count;

    for my $row ($ts->rows) {
      print '[debug]: ', join('|', map { defined $_ ? $_ : 'undef' } @$row), "\n";
    }
  }

  print "\n \n \n \n[debug]: ++++ ==== ++++ ==== ++++ ==== ++++ ==== END OF TABLE DUMP ++++ ==== ++++ ==== ++++ ==== ++++ ==== \n \n \n \n";

=end comment

=cut

  my %bonds;
  for my $ts ($te->table_states) {
    for my $row ($ts->rows) {
      $bonds{$row->[0]} = {
			   rate => $row->[2],
			   maturity => $row->[3],
			   bid => $row->[5],
			   ask => $row->[6],
			   };
    }
  }

  # no bonds were returned, probably due to being a weekend or holiday
  return unless keys(%bonds) > 1;

  for my $symbol (@symbols) {

    # GENERAL FIELDS
    $info{$symbol, 'method'} = 'treasurydirect';
    $info{$symbol, 'symbol'} = $symbol;
    $info{$symbol, 'source'} = $TREASURY_DIRECT_URL;

    # OTHER INFORMATION
    if (exists $bonds{$symbol}) {

      $info{$symbol, 'success'} = 1;
      $info{$symbol, 'currency'} = 'USD';

      $info{$symbol, $_} = $bonds{$symbol}{$_} for keys %{$bonds{$symbol}};

      $info{$symbol, 'price'} = sprintf("%.2f", 0.5*($info{$symbol, 'bid'} + $info{$symbol, 'ask'}));

      $info{$symbol, 'date'} = $date if defined $date;
      $info{$symbol, 'isodate'} = $isodate if defined $isodate;
    }
    else {
      $info{$symbol, 'errormsg'} = 'no match';
    }

  }

  return wantarray() ? %info : \%info;
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

=head1 LABELS RETURNED

Information available from Treasury Direct may include the following labels:

method source symbol rate bid ask price date isodate

=head1 SEE ALSO

treasurydirect.gov

Finance::Quote

=cut
