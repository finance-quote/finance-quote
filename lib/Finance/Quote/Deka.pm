#!/usr/bin/perl -w
#
#    Deka import modul based on Union.pm
#    Version 2016-01-12

package Finance::Quote::Deka;
require 5.005;

use strict;
use LWP::UserAgent;
use HTTP::Request::Common;

# VERSION

sub methods { return (deka => \&deka); }
sub labels { return (deka => [qw/exchange name date isodate price method/]); }

# =======================================================================
# The deka routine gets quotes of DEKA funds (Deka Investments)
# On their website DEKA provides a csv file in the format
#    label1;label2;...
#    symbol1;name1;date1;date_before1;bid1;...
#    symbol2;name2;date2;date_before2,bid2,...
#    ...
#
# This subroutine was written by Andre Joost <andrejoost@gmx.de>

# Convert number separators to US values
sub convert_price {
	$_ = shift;
        tr/.,/,./ ;
	return $_;
}

sub deka
{
  my $quoter = shift;
  my @funds = @_;
  return unless @funds;
  my $ua = $quoter->user_agent;
  my (%fundhash, @q, %info, $tempdate);

  # create hash of all funds requested
  foreach my $fund (@funds)
  {
    $fundhash{$fund} = 0;
  }

  # get csv data
  my $response = $ua->request(GET &dekaurl);


  if ($response->is_success)
  {

    # process csv data
    foreach (split('\015?\012',$response->content))
        {
#      @q = $quoter->parse_csv($_) or next;
      @q = split(/;/) or next;
      next unless (defined $q[0]);
      if (exists $fundhash{$q[0]})
      {
        $fundhash{$q[0]} = 1;


        $info{$q[0], "exchange"} = "DEKA";
        $info{$q[0], "name"}     = $q[1];
        $info{$q[0], "symbol"}   = $q[0];
        $tempdate  = $q[2];
	$quoter->store_date(\%info, $q[0], {eurodate => $tempdate});
        $info{$q[0], "price"}    = convert_price($q[4]);
        $info{$q[0], "last"}     = convert_price($q[4]);

        $info{$q[0], "method"}   = "deka";
        $info{$q[0], "currency"} = $q[8];
        $info{$q[0], "success"}  = 1;
      }
    }

    # check to make sure a value was returned for every fund requested
    foreach my $fund (keys %fundhash)
    {
      if ($fundhash{$fund} == 0)
      {
        $info{$fund, "success"}  = 0;
        $info{$fund, "errormsg"} = "No data returned";
      }
    }
  }
  else
  {
    foreach my $fund (@funds)
    {
      $info{$fund, "success"}  = 0;
      $info{$fund, "errormsg"} = "HTTP error";
    }
  }

  return wantarray() ? %info : \%info;
}

# DEKA provides a csv file named fondspreise.csv containing the prices of all
# their funds for the most recent business day.

sub dekaurl
{
  return "https://www.deka.de/privatkunden/pflichtseiten/fondspreise?service=fondspreislisteExportController&action=exportCsv&typ=inVertrieb";
}

1;

=head1 NAME

Finance::Quote::Deka	- Obtain quotes from DEKA (Wertpapierhaus der Sparkassen).

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %stockinfo = $q->fetch("deka","DE0008474503");

=head1 DESCRIPTION

This module obtains information about DEKA managed funds.

Information returned by this module is governed by DEKA's terms
and conditions.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::DEKA:
exchange, name, date, price, last.

=head1 SEE ALSO

DEKA (Deka Investments), http://www.deka.de/

=cut
