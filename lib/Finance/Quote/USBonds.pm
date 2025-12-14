#!/usr/bin/perl -w
# vi: set ts=2 sw=2 expandtab noai ic showmode showmatch:  
#
# USBonds.pm
# A GNUCash quote source that uses the treasurydirect.gov website to obtain
# current prices for U.S. Treasury bonds, such as E, EE, I, etc.
# The user provides the necessary specifications for their bonds and this
# routine queries the website for the prices.
#
# Kenneth J. Farley
# 2018-02-03
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation; either version 2 of the License, or (at your
# option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write the Free Software Foundation, Inc., 59 Temple
# Place - Suite 330, Boston, MA 02111-1307, USA.
#

package Finance::Quote::USBonds ;
require 5.010 ;

use strict ;
use warnings ;

use LWP::UserAgent ;
use HTTP::Request::Common ;
use HTML::TreeBuilder ;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments', '###';

# VERSION

#
# Define constants.
#

our $DISPLAY    = 'USBonds - US Treasury Bonds';
our @LABELS     = qw/exchange method source symbol currency date isodate version price/;
our $METHODHASH = {subroutine => \&usbonds, 
                   display => $DISPLAY, 
                   labels => \@LABELS};

sub methodinfo {
  return ( 
   usbonds => $METHODHASH,
  );
}

# --- [ labels ] --------------------------------------------------------------
#
# This method also seems to be a requirement of a Finance::Quote module, but
# there doesn't seem to be any documentation of what it is supposed to include,
# or why.
#

sub labels {
  my %m = methodinfo();
  return map {$_ => [@{$m{$_}{labels}}] } keys %m;
}

# --- [ methods ] -------------------------------------------------------------
#
# A Finance::Quote module must have a methods() subroutine, which is called by
# when it loads the module. It's used to determine which methods the module
# provides. Thus, though there are a number of subroutines defined, only those
# we want to make 'public' are included here.
#

sub methods {
  my %m = methodinfo();
  return map {$_ => $m{$_}{subroutine} } keys %m;
}

my $urlBonds = "https://www.treasurydirect.gov/BC/SBCPrice" ;

#
# Package variables, necessary to allow the different subroutines to access the
# same data.
#

my %quotes ;
my ( @listDenomination, @listSeries, @listIssueDate, @listDateNums ) ;
my ( @listQuoteDate, @listPrices, @validSymbols ) ;

# --- [ getTodaysDate ] -------------------------------------------------------
#
# Returns a string that contains today's date in the format 'YYYY-MM-DD'. It uses
# the 'localtime' function, adjusting and formatting the data appropriately.
#

sub getTodaysDate
{
  my $useIsoFormat = $_[0] ;
  if ( defined $useIsoFormat )
  {
    $useIsoFormat = ( $useIsoFormat > 0 ) ;
  }
  else
  {
    $useIsoFormat = ( 0 == 1 ) ;
  }
  my ( $s, $m, $h, $dayToday, $monthToday, $yearToday, $w, $y, $i ) = localtime ;
  $monthToday += 1 ;
  $yearToday  += 1900 ;
  if ( $useIsoFormat )
  {
    $yearToday . '-' . $monthToday . '-' . $dayToday ;
  }
  else
  {
    $monthToday . '/' . $dayToday . '/' . $yearToday ;
  }
}

# --- [ isDateValid ] ---------------------------------------------------------
#
# Savings bonds, like any government organization, have a confusing melange of
# valid issue dates, depending upon the series and denomination. This routine
# will determine, given a set of parameters, whether the bond described is
# valid.
#
# The algorithm, if it can be dignified with that title, calculates an integer
# date value which is 12 times the year added to the month. The number is used
# to compare the date to the acceptable range of dates for the given bond
# series.
#
# Usage: isDateValid ( denom, series, month, year )
#
# Arguments
# denom  : the monetary denomination, in USD.
# series : the series of the bond.
# month  : an integer from 1 (January) to 12 (December).
# year   : a four digit integer representing the year.
#
# Returns a boolean value indicating if the given combination of parameters
# describes a valid bond.
#

sub isDateValid
{
  my $denom   = $_[0] ;
  my $series  = $_[1] ;
  my $datenum = $_[2] + 12 * $_[3] ;
  my $result  = ( 0 == 1 ) ;

  if ( $series eq 'E' )
  {
    $result = ( $datenum > 4 + 1941 * 12 && $datenum < 7 + 1980 * 12 ) ;
    if ( $result && $denom == 10 )
    {
      $result = ( $datenum > 5 + 1944 * 12 && $datenum < 4 + 1950 * 12 ) ;
    }
    if ( $result && $denom == 75 )
    { $result = ( $result && $datenum > 4 + 1964 * 12 ) ; }
    if ( $result && $denom == 200 )
    { $result = ( $result && $datenum > 9 + 1945 * 12 ) ; }
    if ( $result && $denom == 10000 )
    { $result = ( $result && $datenum > 4 + 1952 * 12 ) ; }
  }

  #
  # Series I
  # Issue Dates 1998-09 to 2009-08
  # Denominations : 200 and 10000
  #
  if ( $series eq 'I' )
  {
    $result = ( $datenum > 8 + 1998 * 12 && $datenum < 9 + 2009 * 12 ) ;
    if ( $result && $denom == 200 )
    { $result = ( $result && $datenum > 4 + 1999 * 12 ) ; }
    if ( $result && $denom == 10000 )
    {
      $result = ( $datenum > 4 + 1999 * 12 && $datenum < 12 + 2007 * 12 ) ;
    }
  }

  #
  # Series EE
  # Issue Dates 1980-01 to present
  # Denominations : 50, 75, 100, 200, 500, 1000, 2000, 5000, and 10000
  #
  if ( $series eq 'EE' )
  {
    $result = ( $denom =~ /10{2,4}|50{1,3}|75|20{2,3}/ ) ;
    $result = ( $result && $datenum > 12 + 1979 * 12 ) ;
  }
  $result ;
}

# --- [ buildForm ] -----------------------------------------------------------
#
# Builds a form that is to be 'posted' to the website that provides pricing
# data for bonds. The form contains the minimum data necessary to get data
# from the site. Note that some of the data series stored in the form are just
# blank placeholders.
#
# Arguments
# listDen : a reference to an array of the monetary denomination, in USD.
# listSer : a reference to an array the series of the bond.
# listDat : a reference to an array of issue dates
#
# Returns a form populated with the data provided in the lists.
#

sub buildForm
{
  my ( $yr, $mo ) = ( &getTodaysDate ( 1 ) =~ m/([0-9]+)\-([0-9]+)\-[0-9]+/ ) ;
  my @listDen = @{ $_[0] } ;
  my @listSer = @{ $_[1] } ;
  my @listDat = @{ $_[2] } ;
  my %result =
    (
     SerialNumList       => ' ;' x ( scalar @listDen ),
     RedemptionDate      => $mo . "/" . $yr,
     IssueDateList       => join ( ';', @listDat ) . ';',
     SeriesList          => join ( ';', @listSer ) . ';',
     DenominationList    => join ( ';', @listDen ) . ';',
     IssuePriceList      => ' ;' x ( scalar @listDen ),
     InterestList        => ' ;' x ( scalar @listDen ),
     YTDInterestList     => ' ;' x ( scalar @listDen ),
     ValueList           => ' ;' x ( scalar @listDen ),
     InterestRateList    => ' ;' x ( scalar @listDen ),
     NextAccrualDateList => ' ;' x ( scalar @listDen ),
     MaturityDateList    => ' ;' x ( scalar @listDen ),
     NoteList            => ' ;' x ( scalar @listDen ),
     OldRedemptionDate   => ' ;' x ( scalar @listDen ),
     ViewPos             => '1',
     ViewType            => 'Partial',
     Version             => '6',
     'btnUpdate.x'       => 'UPDATE',
    ) ;
}

# --- [ parseSymbol ] ---------------------------------------------------------
#
# Parses a provided symbol, determines if it is valid, and if so, adds its data
# to the global arrays of information and the global validSymbols list.
#
# The valid symbol pattern is
#
# SS-DDD-YYYY-MM
#
# Where
#   SS   = series I, E, or EE
#   DDD  = denomination 50, 75, 100, 200, 500, 1000 5000 or 10000
#   YYYY = year of issuance
#   MM   = month of issuance
#
# Symbols parsed are checked for validity according to the above rules, and
# return a hopefully helpful indication of what is wrong, whether it be the
# overall format, or the individual tokens of the symbol.
#

sub parseSymbol
{
  my $symbol       = uc $_[0] ;
  my $regexpSymbol = "^([A-Za-z]{1,2})-(\\d{2,5})-(\\d{4})-(\\d{2})" ;
  my ( $ser, $den, $yr, $mo ) = ( $symbol =~ m/$regexpSymbol/ ) ;
  my $okFormat = ( $den && $ser && $yr && $mo ) ;
  my $errorMsg = "" ;
  my $okTokens = ( 1 == 1 ) ;
  if ( $okFormat )
  {
    my $okDenom  = ( $den =~ /10{1,4}|50{1,3}|25|75|200/ ) ;
    my $okSeries = ( $ser =~ /E{1,2}|I/ ) ;
    my $okYear   = ( $yr =~ /194[1-9]|19[5-9]\d|20\d{2}/ ) ;
    my $okMonth  = ( $mo =~ /0[1-9]|1[0-2]/ ) ;
    if ( $okSeries && $okDenom )
    {
      if ( $ser eq 'I' || $ser eq 'EE' )
      { $okDenom = ( $den > 26 ) ; }
      if ( $ser eq 'E' )
      { $okDenom = ( $den != 5000 ) ; }
    }
    my $okDate = &isDateValid ( $den, $ser, $mo, $yr ) ;
    my $okTokens = ( $okDenom && $okSeries && $okYear && $okMonth && $okDate) ;
    if ( $okTokens )
    {
      push @listDenomination, $den ;
      push @listSeries,       $ser ;
      push @listIssueDate,    $mo . "/" . $yr ;
      push @listDateNums,     ( $yr * 12 + $mo - 23296 ) ;
      push @validSymbols,     $symbol ;
    }
    else
    {
      $errorMsg = "Symbol \"" . $symbol . "\" Bad tokens:\n" ;
      if ( ! $okDenom )
      { $errorMsg .= " denomination \"" . $den . "\"" ; }
      if ( ! $okSeries )
      { $errorMsg .= " series \"" . $ser . "\"" ; }
      if ( ! $okYear )
      { $errorMsg .= " year \"" . $yr . "\"" ; }
      if ( ! $okMonth )
      { $errorMsg .= " month \"" . $mo . "\"" ; }
      if ( ! $okDate )
      { $errorMsg .= " date \"" . $yr . "-" . $mo . "\"" ; }
    }
  }
  else
  {
    $errorMsg = "Symbol \"" . $symbol . "\" incorrect format" ;
  }
  $quotes { $symbol, "success" } = $okFormat && $okTokens ;
  unless ( $okFormat && $okTokens )
  {
    $quotes { $symbol, "errormsg" } = $errorMsg ;
    $quotes { $symbol, "success" } = 0;
  }
}

# --- [ getQuoteDates ] ----------------------------------------------------
#
# Interest is accrued for some bonds every 6 months, and for others monthly.
# The treasurydirect bond pricing calculator provides a 'next accrual date'
# field for each bond.
# This routine traverses the list of valid bonds and finds the latest accrual
# date that has passed. By doing so, when the pricing information is provided
# to GnuCash, it will not generate duplicate quotes, even if this module is
# used multiple times in the same month.
#
# The algorithm used is as follows:
# (1) Get the date today from the 'getTodaysDate' function.
# (2) Starting last month, get the next accrual date for all the bonds.
# (3) For any accrual dates that are less than or equal to this month, record
#     them in the appropriate list.
# (4) Go to the next month back, and get the next accrual date for any bonds
#     that have not got any yet.
# (5) Continue to the next month back for any bonds that aren't matched, etc.
#
# All the quote dates are saved as the first day of the month, or '01/MM/YYYY'
# and an isodate of 'YYYY-MM-01'.
#

sub getQuoteDates
{
  my ( $yr, $mo ) = ( &getTodaysDate ( 1 ) =~ m/([0-9]+)\-([0-9]+)\-[0-9]+/ ) ;
  my $dateNumToday = $yr * 12 + $mo - 23296 ;
  @listQuoteDate = split ';', ( '-;' x ( scalar @validSymbols ) ) ;
  my $userAgent = LWP::UserAgent->new ;

  my $moNext = $mo ;
  my $yrNext  = $yr ;
  for ( my $deltaMonth = 1 ; $deltaMonth <= 6 ; $deltaMonth++ )
  {
    $moNext-- ;
    if ( $moNext < 1 )
    {
      $moNext += 12 ;
      $yrNext  -= 1 ;
    }
    my $countItems = 0 ;
    my ( @listDat, @listDen, @listSer ) ;
    for ( my $index = 0 ; $index < ( scalar @validSymbols ) ; $index++ )
    {
      if ( $listQuoteDate [ $index ] eq "-" )
      {
        push @listDat, $listDateNums [ $index ] ;
        push @listDen, $listDenomination [ $index ] ;
        push @listSer, $listSeries [ $index ] ;
        $countItems++ ;
      }
    }
    if ( $countItems > 0 )
    {
      my %formQuery = &buildForm ( \@listDen, \@listSer, \@listDat ) ;
      $formQuery{ 'RedemptionDate' } = $moNext . '/' . $yrNext ;
      my $resData = $userAgent->post ( $urlBonds, \%formQuery ) ;
      if ( $resData->is_success )
      {
        my $treeQuery = HTML::TreeBuilder->new_from_content ( $resData->content ) ;
        $treeQuery->elementify () ;
        my $valueQuery =
          (
           $treeQuery->look_down
           (
            sub
            {
              $_[0]->tag() eq 'input'
                and $_[0]->attr ( 'type' ) eq 'hidden'
                and $_[0]->attr ( 'name' ) eq 'NextAccrualDateList'
            }
           )
          ) ;
        if ( defined ( $valueQuery ) )
        {
          my @listNext = split ";", $valueQuery->{value} ;
          my $indexRes = 0 ;
          for ( my $indexDate = 0 ; $indexDate < ( scalar @validSymbols ) ; $indexDate++ )
          {
            if ( $listQuoteDate [ $indexDate ] eq "-" )
            {
              my $dateNum = $listNext [ $indexRes ] ;
              if ( $dateNum <= $dateNumToday )
              {
                my $yr = int ( ( $listNext [ $indexRes ] + 23296 ) / 12 ) ;
                my $mo = ( $listNext [ $indexRes ] + 23296 ) % 12 ;
                if ( $mo < 1 )
                {
                  $mo += 12 ;
                  $yr -= 1 ;
                }
                if ( $mo < 10 ) { $mo = '0' . $mo ; }
                $listQuoteDate [ $indexDate ] = $mo . '/' . $yr ;
              }
              $indexRes++ ;
            }
          }
        }
      }
    }
  }
} # getQuoteDates

# --- [ getQuotes ] -----------------------------------------------------------
#
# Uses the lists that have been built pertaining to the bonds, to get the
# current prices by posting a form with the data to the treasurydirect website.
# The prices are extracted from the resulting data using HTML::TreeBuilder.
#

sub getQuotes
{
  my %formBonds = &buildForm ( \@listDenomination, \@listSeries, \@listIssueDate ) ;
  my $userAgent = LWP::UserAgent->new ;
  my $resData   = $userAgent->post ( $urlBonds, \%formBonds ) ;
  if ( $resData->is_success )
  {
    my $treeBonds = HTML::TreeBuilder->new_from_content ( $resData->content ) ;
    $treeBonds->elementify () ;
    my $valueBonds =
      ( $treeBonds->look_down
        ( sub
          {
            $_[0]->tag() eq 'input' and
              $_[0]->attr ( 'type' ) eq 'hidden' and
              $_[0]->attr ( 'name' ) eq 'ValueList'
          }
        )
      ) ;
    if ( defined ( $valueBonds ) )
    {
      $valueBonds->{value} =~ s/;$// ;
      @listPrices = split ';', $valueBonds->{value} ;
    }
  }
} # end getQuotes

# --- [ usbonds ] -------------------------------------------------------------
#
# The main routine, which is the option that will be selected within GnuCash to
# get prices for bonds.
#
# The algorithm used is as follows:
#
# (1) Parse the symbol to determine the series, face value, issue date, etc.
# (2) For the valid symbols that result from the parsing, get quotes.
# (3) Build the hash table by adding all the valid symbols with their pertin-
#     ent data.
# (4) Return the hash table.
#
# Arguments
# quoter  : string that identifies the module. This argument is ignored.
# symbol1 : 1st symbol
# symbol2 : 2nd symbol
#    .
#    .
#    .
# symboln : nth symbol
#

sub usbonds
{
  my $quoter  = shift ;
  my @symbols = @_ ;

  return unless @symbols ;

  foreach my $symbol ( @symbols )
  {
    &parseSymbol ( $symbol ) ;
  }

  if ( scalar @validSymbols > 0 )
  {
    &getQuotes ;
    &getQuoteDates ;

    ### listPrices: @listPrices

    for ( my $index = 0 ; $index < scalar @validSymbols ; $index++ )
    {
      my ( $mo, $yr ) = ( $listQuoteDate [ $index ] =~ m/([0-9]+)\/([0-9]+)/ ) ;
      my $keyNow = $validSymbols [ $index ] ;
      $quotes { $keyNow, "exchange" } = "Treasury Direct" ;
      $quotes { $keyNow, "method"   } = "usbonds" ;
      $quotes { $keyNow, "price"    } = $listPrices [ $index ] ;
      $quotes { $keyNow, "last"     } = $listPrices [ $index ] ;
      $quotes { $keyNow, "symbol"   } = $validSymbols [ $index ] ;
      $quotes { $keyNow, "currency" } = "USD" ;
      $quotes { $keyNow, "source"   } = "USBonds" ;
      $quotes { $keyNow, "date"     } = $mo . "/01/" . $yr ;
      $quotes { $keyNow, "isodate"  } = $yr . "-" . $mo . "-01" ;
      $quotes { $keyNow, "version"  } = '1.10' ;
      $quotes { $keyNow, "success"  } = 1 ;
    }
  }
  return wantarray() ? %quotes : \%quotes;
}

1 ;

=head1 NAME

Finance::Quote::USBonds - Obtain quotes for US Federal Bonds in the E, EE, or I series
from the Treasury Direct website, http://www.treasurydirect.gov.

=head1 SYNOPSIS

    use Finance::Quote ;

    $q = Finance::Quote->new ;

    %quote = $q->fetch ( "usbonds", "\EE-100-1993-10" ) ;

=head1 DESCRIPTION

Module obtains quote information from the Treasury Direct website, www.treasurydirect.gov.
Given a bond symbol, obtains the current prices for it.

The symbol nomenclature is as follows:

SS-DDDDD-YYYY-MM

Where
     SS    = series (EE, E, or I)
     DDDDD = denomination
     YYYY  = year issued
     MM    = month issued

For example, 'EE-500-1988-02'

The symbols supplied are checked for format and validity. For example, bonds
were only issued after 1942, only the specific denominations issued for EE
bonds are allowed, etc.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::USBonds:
exchange method source symbol currency date isodate version price

=head1 SEE ALSO

Treasury bond value web interface - http://www.treasurydirect.gov/BC/SBCPrice

Finance::Quote

=head1 AUTHOR

Kenneth J. Farley

=cut
