#!/usr/bin/perl -w
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@cpan.org>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#
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
#
#
# This code derived from Padzensky's work on package Finance::YahooQuote,
# but extends its capabilites to encompas a greater number of data sources.
#
# This code was developed as part of GnuCash <http://www.gnucash.org/>

package Finance::Quote;

use strict;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments', '###';

use Module::Load;
use Exporter ();
use Carp;
use Finance::Quote::UserAgent;
use HTTP::Request::Common;
use Encode;
use JSON qw( decode_json );

use vars qw/@ISA @EXPORT @EXPORT_OK @EXPORT_TAGS
            $TIMEOUT @MODULES %MODULES %METHODS $AUTOLOAD
            @CURRENCY_RATES_MODULES $USE_EXPERIMENTAL_UA/;

# VERSION

@CURRENCY_RATES_MODULES = qw/
    AlphaVantage
    ECB
    Fixer
    OpenExchange
/;

@MODULES = qw/
    AEX
    ASEGR
    ASX
    AlphaVantage
    BSEIndia
    Bloomberg
    Bourso
    CSE
    Cdnfundlibrary
    Comdirect
    Currencies
    DWS
    Deka
    FTfunds
    Fidelity
    Finanzpartner
    Fondsweb
    Fool
    Fundata
    GoldMoney
    HU
    IEXCloud
    IndiaMutual
    MStaruk
    MorningstarAU
    NSEIndia
    NZX
    OnVista
    Oslobors
    SEB
    SIX
    Tradeville
    TSP
    TMX
    Tiaacref
    Troweprice
    USFedBonds
    Union
    YahooJSON
    ZA
/;

@ISA    = qw/Exporter/;
@EXPORT = ();
@EXPORT_OK = qw/fidelity troweprice asx tiaacref
                currency_lookup/;
@EXPORT_TAGS = ( all => [@EXPORT_OK]);

$USE_EXPERIMENTAL_UA = 0;

################################################################################
#
# Private Class Methods
#
################################################################################
# Autoload method for obsolete methods.  This also allows people to
# call methods that objects export without having to go through fetch.

sub AUTOLOAD {
  my $method = $AUTOLOAD;
  (my $name = $method) =~ s/.*:://;

  # Force the dummy object (and hence default methods) to be loaded.
  _dummy();

  if (exists($METHODS{$name})) {
    no strict 'refs'; ## no critic
    
    *$method = sub { 
      my $this = ref($_[0]) ? shift : _dummy();
      $this->fetch($name, @_);
    };

    return &$method;
  }

  carp "$AUTOLOAD does not refer to a known method.";
}

# Dummy destroy function to avoid AUTOLOAD catching it.
sub DESTROY { return; }

# _convert (private object method)
#
# This function converts between one currency and another.  It expects
# to receive a hashref to the information, a reference to a list
# of the stocks to be converted, and a reference to a  list of fields
# that conversion should apply to.

{
  my %conversion;   # Conversion lookup table.

  sub _convert {
    my $this = shift;
    my $info = shift;
    my $stocks = shift;
    my $convert_fields = shift;
    my $new_currency = $this->{"currency"};

    # Skip all this unless they actually want conversion.
    return unless $new_currency;

    foreach my $stock (@$stocks) {
      my $currency;

      # Skip stocks that don't have a currency.
      next unless ($currency = $info->{$stock,"currency"});

      # Skip if it's already in the same currency.
      next if ($currency eq $new_currency);

      # Lookup the currency conversion if we haven't
      # already.
      unless (exists $conversion{$currency,$new_currency}) {
        $conversion{$currency,$new_currency} =
          $this->currency($currency,$new_currency);
      }

      # Make sure we have a reasonable currency conversion.
      # If we don't, mark the stock as bad.
      unless ($conversion{$currency,$new_currency}) {
        $info->{$stock,"success"} = 0;
        $info->{$stock,"errormsg"} =
          "Currency conversion failed.";
        next;
      }

      # Okay, we have clean data.  Convert it.  Ideally
      # we'd like to just *= entire fields, but
      # unfortunately some things (like ranges,
      # capitalisation, etc) don't take well to that.
      # Hence we pull out any numbers we see, convert
      # them, and stick them back in.  That's pretty
      # yucky, but it works.

      foreach my $field (@$convert_fields) {
        next unless (defined $info->{$stock,$field});

        $info->{$stock,$field} = $this->scale_field($info->{$stock,$field},$conversion{$currency,$new_currency});
      }

      # Set the new currency.
      $info->{$stock,"currency"} = $new_currency;
    }
  }
}

# =======================================================================
# _dummy (private function)
#
# _dummy returns a Finance::Quote object.  I'd really rather not have
# this, but to maintain backwards compatibility we hold on to it.
{
  my $dummy_obj;
  sub _dummy {
    return $dummy_obj ||= Finance::Quote->new;
  }
}

# _load_module (private class method)
# _load_module loads a module(s) and registers its various methods for
# use.

sub _load_modules {
  my $class = shift;
  my $baseclass = ref $class || $class;

  my @modules = @_;

  # Go to each module and use them.  Also record what methods
  # they support and enter them into the %METHODS hash.

  foreach my $module (@modules) {
    my $modpath = "${baseclass}::${module}";
    unless (defined($MODULES{$modpath})) {

      eval {
        load $modpath;
        $MODULES{$modpath}   = 1;

        my %methodhash       = $modpath->methods;
        my %labelhash        = $modpath->labels;
        my $curr_fields_func = $modpath->can("currency_fields") || \&default_currency_fields;
        my @currency_fields  = &$curr_fields_func;
        my %seen;
        @currency_fields     = grep {!$seen{$_}++} @currency_fields;

        foreach my $method (keys %methodhash) {
          push (@{$METHODS{$method}},
              { function => $methodhash{$method},
              labels   => $labelhash{$method},
              currency_fields => \@currency_fields});
        }
      };
      carp $@ if $@;
    }
  }
}

# _smart_compare (private method function)
#
# This function compares values where the method depends on the
# type of the parameters.
#  val1, val2
#  scalar,scaler - test for substring match
#  scalar,regex  - test val1 against val2 regex
#  array,scalar  - return true if any element of array substring matches scalar
#  array,regex   - return true if any element of array matches regex
sub _smart_compare {
  my ($val1, $val2) = @_;
 
  if ( ref $val1 eq 'ARRAY' ) {
    if ( ref $val2 eq 'Regexp' ) {
      my @r = grep {$_ =~ $val2} @$val1;
      return @r > 0;
    }
    else {
      my @r = grep {$_ =~ /$val2/} @$val1;
      return @r > 0;
    }
  }
  else {
    if ( ref $val2 eq 'Regexp' ) {
      return $val1 =~ $val2;
    }
    else {
      return index($val1, $val2) > -1
    }
  }
}

# This is a list of fields that will be automatically converted during
# currency conversion.  If a module provides a currency_fields()
# function then that list will be used instead.

sub get_default_currency_fields {
  return qw/last high low net bid ask close open day_range year_range
            eps div cap nav price/;
}

sub get_default_timeout {
  return $TIMEOUT;
}

# get_methods returns a list of sources which can be passed to fetch to
# obtain information.

sub get_methods {
  # Create a dummy object to ensure METHODS is populated
  my $t = Finance::Quote->new();
  return(wantarray ? keys %METHODS : [keys %METHODS]);
}

# =======================================================================
# new (public class method)
#
# Returns a new Finance::Quote object.
#
# Arguments ::
#    - zero or more module names from the Finance::Quote::get_sources list
#    - zero or more named parameters, passes as name => value
#
# Named Parameters ::
#    - timeout           # timeout in seconds for web requests
#    - failover          # boolean value indicating if failover is acceptable
#    - fetch_currency    # currency code for fetch results
#    - required_labels   # array of required labels in fetch results
#    - <module-name>     # hash specific to various Finance::Quote modules
#
# new()                               # default constructor
# new('a', 'b')                       # load only modules a and b
# new(timeout => 30)                  # load all default modules, set timeout
# new('a', fetch_currency => 'X')     # load only module a, use currency X for results
# new('z' => {API_KEY => 'K'})        # load all modules, pass hash to module z constructor
# new('z', 'z' => {API_KEY => 'K'})   # load only module z and pass hash to its constructor
#
# Enivornment Variables ::
#    - FQ_LOAD_QUOTELET  # if no modules named in argument list, use ones in this variable
#
# Return Value ::
#    - Finanace::Quote object

sub new {
  # Create and bless object
  my $self = shift;
  my $class = ref($self) || $self;

  my $this = {};
  bless $this, $class;

  # To add a named parameter:
  # 0. Document it in the POD for new
  # 1. Add a default value for $this->{object-name}
  # 2. Add the 'user-visible-name' => [type, object-name] to %named_parameter

  # Default values
  $this->{FAILOVER}       = 1;
  $this->{REQUIRED}       = [];
  $this->{TIMEOUT}        = $TIMEOUT if defined($TIMEOUT);
  $this->{currency_rates} = {order => ['AlphaVantage']};

  # Sort out arguments
  my %named_parameter = (timeout         => ['', 'TIMEOUT'],
                         failover        => ['', 'FAILOVER'],
                         fetch_currency  => ['', 'currency'],
                         required_labels => ['ARRAY', 'REQUIRED'],
                         currency_rates  => ['HASH', 'currency_rates']);

  $this->{module_specific_data} = {};
  my @load_modules = ();

  for (my $i = 0; $i < @_; $i++) {
    if (exists $named_parameter{$_[$i]}) {
      die "missing value for named parameter $_[$i]" if $i + 1 == @_;
      die "unexpect type for value of named parameter $_[$i]" if ref $_[$i+1] ne $named_parameter{$_[$i]}[0];

      $this->{$named_parameter{$_[$i]}[1]} = $_[$i+1];
      $i += 1;
    }
    elsif ($i + 1 < @_ and ref $_[$i+1] eq 'HASH') {
      $this->{module_specific_data}->{$_[$i]} = $_[$i+1];
      $i += 1;
    }
    elsif ($_[$i] eq '-defaults') {
      push (@load_modules, @MODULES);
    }
    else {
      push (@load_modules, $_[$i]);
    }
  }

  # Honor FQ_LOAD_QUOTELET if @load_modules is empty
  if ($ENV{FQ_LOAD_QUOTELET} and !@load_modules) {
    @load_modules = split(' ',$ENV{FQ_LOAD_QUOTELET});
  }
  elsif (@load_modules == 0) {
    push(@load_modules, @MODULES);
  }

  $this->_load_modules(@load_modules);

  # Load the currency rate methods
  my %currency_check = map { $_ => 1 } @CURRENCY_RATES_MODULES;
  $this->{currency_rate_method} = [];
  foreach my $method (@{$this->{currency_rates}->{order}}) {
    unless (defined($currency_check{$method})) {
      carp "Unknown curreny rates method: $method";
      return;
    }

    my $method_path = "${class}::CurrencyRates::${method}";
    eval {
      autoload $method_path;
      my $args = exists $this->{currency_rates}->{lc($method)} ? $this->{currency_rates}->{lc($method)} : {};
      my $rate = $method_path->new($args);
      die unless defined $rate;
      
      push(@{$this->{currency_rate_method}}, $rate);
    };

    if ($@) {
      next;
    }
  }

  return $this;
}

sub set_default_timeout {
  $TIMEOUT  = shift;
}

################################################################################
#
# Private Object Methods
#
################################################################################

# _require_test (private object method)
#
# This function takes an array.  It returns true if all required
# labels appear in the arrayref.  It returns false otherwise.
#
# This function could probably be made more efficient.

sub _require_test {
  my $this = shift;
  my %available;
  @available{@_} = ();  # Ooooh, hash-slice.  :)
  my @required = @{$this->{REQUIRED}};
  return 1 unless @required;
  for (my $i = 0; $i < @required; $i++) {
    return 0 unless exists $available{$required[$i]};
  }
  return 1;
}

################################################################################
#
# Public Object Methods
#
################################################################################

# If $str ends with a B like "20B" or "1.6B" then expand it as billions like
# "20000000000" or "1600000000".
#
# This is done with string manipulations so floating-point rounding doesn't
# produce spurious digits for values like "1.6" which aren't exactly
# representable in binary.
#
# Is "B" for billions the only abbreviation from Yahoo?
# Could extend and rename this if there's also millions or thousands.
#
# For reference, if the value was just for use within perl then simply
# substituting to exponential "1.5e9" might work.  But expanding to full
# digits seems a better idea as the value is likely to be printed directly
# as a string.
sub B_to_billions {
  my ($self,$str) = @_;

  # B_to_billions() $str
  if ($str =~ s/B$//i) {
    $str = $self->decimal_shiftup ($str, 9);
  }
  return $str;
}

# $str is a number like "123" or "123.45"
# return it with the decimal point moved $shift places to the right
# must have $shift>=1
# eg. decimal_shiftup("123",3)    -> "123000"
#     decimal_shiftup("123.45",1) -> "1234.5"
#     decimal_shiftup("0.25",1)   -> "2.5"
#
sub decimal_shiftup {
  my ($self, $str, $shift) = @_;

  # delete decimal point and set $after to count of chars after decimal.
  # Leading "0" as in "0.25" is deleted too giving "25" so as not to end up
  # with something that might look like leading 0 for octal.
  my $after = ($str =~ s/(?:^0)?\.(.*)/$1/ ? length($1) : 0);

  $shift -= $after;
  # now $str is an integer and $shift is relative to the end of $str

  if ($shift >= 0) {
    # moving right, eg. "1234" becomes "12334000"
    return $str . ('0' x $shift);  # extra zeros appended
  } else {
    # negative means left, eg. "12345" becomes "12.345"
    # no need to prepend zeros since demanding initial $shift>=1
    substr ($str, $shift,0, '.');  # new '.' at shifted spot from end
    return $str;
  }
}

# =======================================================================
# fetch (public object method)
#
# Fetch is a wonderful generic fetcher.  It takes a method and stuff to
# fetch.  It's a nicer interface for when you have a list of stocks with
# different sources which you wish to deal with.
sub fetch {
  my $this = ref($_[0]) ? shift : _dummy();

  my $method = lc(shift);
  my @stocks = @_;

  unless (exists $METHODS{$method}) {
    carp "Undefined fetch-method $method passed to ".
         "Finance::Quote::fetch";
    return;
  }

  # Failover code.  This steps through all available methods while
  # we still have failed stocks to look-up.  This loop only
  # runs a single time unless FAILOVER is defined.
  my %returnhash = ();

  foreach my $methodinfo (@{$METHODS{$method}}) {
    my $funcref = $methodinfo->{"function"};
    next unless $this->_require_test(@{$methodinfo->{"labels"}});
    my @failed_stocks = ();
    %returnhash = (%returnhash,&$funcref($this,@stocks));

    foreach my $stock (@stocks) {
      push(@failed_stocks,$stock)
        unless ($returnhash{$stock,"success"});
    }

    $this->_convert(\%returnhash,\@stocks,
                    $methodinfo->{"currency_fields"});

    last unless $this->{FAILOVER};
    last unless @failed_stocks;
    @stocks = @failed_stocks;
  }

  return wantarray() ? %returnhash : \%returnhash;
}

sub get_failover {
  my $self = shift;
  return $self->{FAILOVER};
}

sub get_fetch_currency {
  my $self = shift;
  return $self->{currency};
}

sub get_required_labels {
  my $self = shift;
  return $self->{REQUIRED};
}

sub get_timeout {
  my $self = shift;
  return $self->{TIMEOUT};
}

sub get_user_agent {
  my $this = shift;

  return $this->{UserAgent} if $this->{UserAgent};

  my $ua;

  if ($USE_EXPERIMENTAL_UA) {
    $ua = Finance::Quote::UserAgent->new;
  } else {
    $ua = LWP::UserAgent->new;
  }

  $ua->timeout($this->{TIMEOUT}) if defined($this->{TIMEOUT});
  $ua->env_proxy;

  $this->{UserAgent} = $ua;

  return $ua;
}

sub isoTime {
  my ($self,$timeString) = @_ ;
  $timeString =~ tr/ //d ;
  $timeString = uc $timeString ;
  my $retTime = "00:00"; # return zero time if unparsable input
  if ($timeString=~m/^(\d+)[\.:UH](\d+)(AM|PM)?/) {
    my ($hours,$mins)= ($1-0,$2-0) ;
    $hours-=12 if ($hours==12);
    $hours+=12 if ($3 && ($3 eq "PM")) ;
    if ($hours>=0 && $hours<=23 && $mins>=0 && $mins<=59 ) {
      $retTime = sprintf ("%02d:%02d", $hours, $mins) ;
    }
  }
  return $retTime;
}

sub set_failover {
  my $self          = shift;
  $self->{FAILOVER} = shift;
}

sub set_fetch_currency {
  my $self          = shift;
  $self->{currency} = shift;
}

sub set_required_labels {
  my $self          = shift;
  $self->{REQUIRED} = shift;
}

sub set_timeout {
  my $self         = shift;
  $self->{TIMEOUT} = shift;
}

# =======================================================================
# store_date (public object method)
#
# Given the various pieces of a date, this functions figure out how to
# store them in both the pre-existing US date format (mm/dd/yyyy), and
# also in the ISO date format (yyyy-mm-dd).  This function expects to
# be called with the arguments:
#
# (inforef, symbol_name, data_hash)
#
# The components of date hash can be any of:
#
# usdate   - A date in mm/dd/yy or mm/dd/yyyy
# eurodate - A date in dd/mm/yy or dd/mm/yyyy
# isodate  - A date in yy-mm-dd or yyyy-mm-dd, yyyy/mm/dd, yyyy.mm.dd, or yyyymmdd
# year   - The year in yyyy
# month  - The month in mm or mmm format (i.e. 07 or Jul)
# day  - The day
# today  - A flag to indicate todays date should be used.
#
# The separator for the *date forms is ignored.  It can be any
# non-alphanumeric character.  Any combination of year, month, and day
# values can be provided.  Missing fields are filled in based upon
# today's date.
#
sub store_date
{
    my $this = shift;
    my $inforef = shift;
    my $symbol = shift;
    my $piecesref = shift;

    my ($year, $month, $day, $this_month, $year_specified);
    my %mnames = (jan => 1, feb => 2, mar => 3, apr => 4, may => 5, jun => 6,
      jul => 7, aug => 8, sep => 9, oct =>10, nov =>11, dec =>12);

    ### store_date symbol: $symbol
    ### store_date pieces: $piecesref

    # Default to today's date.
    ($month, $day, $year) = (localtime())[4,3,5];
    $month++;
    $year += 1900;
    $this_month = $month;
    $year_specified = 0;

    # Process the inputs
    if ((defined $piecesref->{isodate}) && ($piecesref->{isodate})) {
      if ($piecesref->{isodate} =~ /^([0-9]{4})([0-9]{2})([0-9]{2})$/) {
        ($year, $month, $day) = ($1, $2, $3);
      }
      else {
        ($year, $month, $day) = ($piecesref->{isodate} =~ m|([0-9]{4})\W+(\w+)\W+(\w+)|);
      }

      $year += 2000 if $year < 100;
      $year_specified = 1;

      ### format: printf "isodate %s -> Day %d, Month %s, Year %d\n", $piecesref->{isodate}, $day, $month, $year
    }

    if ((defined $piecesref->{usdate}) && ($piecesref->{usdate})) {
      ($month, $day, $year) = ($piecesref->{usdate} =~ /(\w+)\W+(\d+)\W+(\d+)/);
      $year += 2000 if $year < 100;
      $year_specified = 1;

      ### format: printf "usdate %s -> Day %d, Month %s, Year %d\n", $piecesref->{usdate}, $day, $month, $year
    }

    if ((defined $piecesref->{eurodate}) && ($piecesref->{eurodate})) {
        ($day, $month, $year) = ($piecesref->{eurodate} =~ /(\d+)\W+(\w+)\W+(\d+)/);
      $year += 2000 if $year < 100;
      $year_specified = 1;

      ### format: printf "eurodate %s -> Day %d, Month %s, Year %d\n", $piecesref->{eurodate}, $day, $month, $year
    }

    if (defined ($piecesref->{year})) {
      $year = $piecesref->{year};
      $year += 2000 if $year < 100;
      $year_specified = 1;

      ### format: printf "year %s -> Year %d\n", $piecesref->{year}, $year
    }

    if (defined ($piecesref->{month})) {
      $month = $piecesref->{month};

      ### format: printf "month %s -> Month %s\n", $piecesref->{month}, $month
    }

    if (defined ($piecesref->{day})) {
      $day = $piecesref->{day};

      ### format: printf "day %s -> Day %d\n", $piecesref->{day}, $day
    }

    $month = $mnames{lc(substr($month,0,3))} if ($month =~ /\D/);
    $year-- if (($year_specified == 0) && ($this_month < $month));

    ### format: printf "Final Year-Month-Day -> %04d-%02d-%02d\n", $year, $month, $day

    $inforef->{$symbol, "date"} =  sprintf "%02d/%02d/%04d", $month, $day, $year;
    $inforef->{$symbol, "isodate"} = sprintf "%04d-%02d-%02d", $year, $month, $day;
}

################################################################################
#
# Public Class or Object Methods
#
################################################################################

# =======================================================================
# Helper function that can scale a field.  This is useful because it
# handles things like ranges "105.4 - 108.3", and not just straight fields.
#
# The function takes a string or number to scale, and the factor to scale
# it by.  For example, scale_field("1023","0.01") would return "10.23".

sub scale_field {
  shift if ref $_[0]; # Shift off the object, if there is one.

  my ($field, $scale) = @_;
  my @chunks = split(/([^0-9.])/,$field);

  for (my $i=0; $i < @chunks; $i++) {
    next unless $chunks[$i] =~ /\d/;
    $chunks[$i] *= $scale;
  }
  return join("",@chunks);
}

# =======================================================================
# currency (public object method)
#
# currency allows the conversion of one currency to another.
#
# Usage: $quoter->currency("USD","AUD");
#  $quoter->currency("15.95 USD","AUD");
#
# undef is returned upon error.

sub currency {
  my $this = ref($_[0]) ? shift : _dummy();

  my ($from_code, $to_code) = @_;
  return unless ($from_code and $to_code);

  $from_code =~ s/^\s*(\d*\.?\d*)\s*//;
  my $amount = $1 || 1;

  $to_code   = uc($to_code);
  $from_code = uc($from_code);

  return $amount if ($from_code eq $to_code); # Trivial case.

  my $ua = $this->get_user_agent;
  
  foreach my $rate (@{$this->{currency_rate_method}}) {
    ### rate: ref($rate)
    my $final = eval {
      my ($from, $to) = $rate->multipliers($ua, $from_code, $to_code);

      die("Failed to find currency rates for $from_code or $to_code") unless defined $from and defined $to;

      ### to weight  : $to
      ### from weight: $from
      ### amount     : $amount

      # Is from closest to (amount, to, amount * to)?
      # (amount * to) / from
      my $delta  = abs($amount - $from);
      my $result = ($amount/$from) * $to;
      ### amount/from -> delta/result : ($delta, $result)
      if ($delta > abs($to - $from)) {
        $delta = abs($to - $from);
        $result = ($to/$from) * $amount;
        ### to/from -> delta/result : ($delta, $result)
      }
      if ($delta > abs($amount*$to - $from)) {
        $delta = abs($amount*$to - $from);
        $result = ($amount * $to)/$from;
        ### (amount * to)/from -> delta/result : ($delta, $result)
      }

      return $result;
    };

    if ($@) {
      ### Rate Error: chomp($@), $@
      next;
    }

    return $final;
  }

  return;
}

# =======================================================================
# currency_lookup (public object method)
#
# search for available currency codes
#
# Usage: 
#   $currency = $quoter->currency_lookup();
#   $currency = $quoter->currency_lookup( name => "Dollar");
#   $currency = $quoter->currency_loopup( country => qw/denmark/i );
#   $currency = $q->currency_lookup(country => qr/united states/i, number => 840);
#
# If more than one lookup parameter is given all must match for
# a currency to match.
#
# undef is returned upon error.

sub currency_lookup {
  my $this = ref $_[0] ? shift : _dummy();

  my %params = @_;
  my $currencies = Finance::Quote::Currencies::known_currencies();

  my %attributes = map {$_ => 1} map {keys %$_} values %$currencies;

  for my $key (keys %params ) {
    if ( ! exists $attributes{$key}) {
      warn "Invalid parameter: $key";
      return;
    }
  }
  
  while (my ($tag, $check) = each(%params)) {
    $currencies = {map {$_ => $currencies->{$_}} grep {_smart_compare($currencies->{$_}->{$tag}, $check)} keys %$currencies};
  }
  
  return $currencies;
}

# =======================================================================
# parse_csv (public object method)
#
# Grabbed from the Perl Cookbook. Parsing csv isn't as simple as you thought!
#
sub parse_csv
{
    shift if (ref $_[0]); # Shift off the object if we have one.
    my $text = shift;      # record containing comma-separated values
    my @new  = ();

    push(@new, $+) while $text =~ m{
        # the first part groups the phrase inside the quotes.
        # see explanation of this pattern in MRE
        "([^\"\\]*(?:\\.[^\"\\]*)*)",?
           |  ([^,]+),?
           | ,
       }gx;
       push(@new, undef) if substr($text, -1,1) eq ',';

       return @new;      # list of values that were comma-separated
}

# =======================================================================
# parse_csv_semicolon (public object method)
#
# Grabbed from the Perl Cookbook. Parsing csv isn't as simple as you thought!
#
sub parse_csv_semicolon
{
    shift if (ref $_[0]); # Shift off the object if we have one.
    my $text = shift;      # record containing comma-separated values
    my @new  = ();

    push(@new, $+) while $text =~ m{
        # the first part groups the phrase inside the quotes.
        # see explanation of this pattern in MRE
        "([^\"\\]*(?:\\.[^\"\\]*)*)";?
           |  ([^;]+);?
           | ;
       }gx;
       push(@new, undef) if substr($text, -1,1) eq ';';

       return @new;      # list of values that were comma-separated
}

###############################################################################
#
# Legacy Class Methods
#
###############################################################################

sub sources {
  return get_methods();
}

sub default_currency_fields {
  return get_default_currency_fields();
}

###############################################################################
#
# Legacy Class or Object Methods
#
###############################################################################

# =======================================================================
# set_currency (public object method)
#
# set_currency allows information to be requested in the specified
# currency.  If called with no arguments then information is returned
# in the default currency.
#
# Requesting stocks in a particular currency increases the time taken,
# and the likelyhood of failure, as additional operations are required
# to fetch the currency conversion information.
#
# This method should only be called from the quote object unless you
# know what you are doing.

sub set_currency {
  if (@_ == 1 or !ref($_[0])) {
    # Direct or class call - there is no class default currency
    return;
  }

  my $this = shift;
  if (defined($_[0])) {
    $this->set_fetch_currency($_[0]);
  }

  return $this->get_fetch_currency();
}

# =======================================================================
# Timeout code.  If called on a particular object, then it sets
# the timout for that object only.  If called as a class method
# (or as Finance::Quote::timeout) then it sets the default timeout
# for all new objects that will be created.

sub timeout {
  if (@_ == 1 or !ref($_[0])) {
    # Direct or class call
    Finance::Quote::set_default_timeout(shift);
    return Finance::Quote::get_default_timeout();
  }

  # Otherwise we were called through an object.  Yay.
  # Set the timeout in this object only.
  my $this = shift;
  $this->set_timeout(shift);
  return $this->get_timeout();
}

###############################################################################
#
# Legacy Object Methods
#
###############################################################################

# =======================================================================
# failover (public object method)
#
# This sets/gets whether or not it's acceptable to use failover techniques.

sub failover {
  my $this = shift;
  my $value = shift;

  $this->set_failover($value) if defined $value;
  return $this->get_failover();
}

# =======================================================================
# require_labels (public object method)
#
# Require_labels indicates which labels are required for lookups.  Only methods
# that have registered all the labels specified in the list passed to
# require_labels() will be called.
#
# require_labels takes a list of required labels.  When called with no
# arguments, the require list is cleared.
#
# This method always succeeds.

sub require_labels {
  my $this = shift;
  my @labels = @_;
  $this->set_required_labels(\@labels);
  return;
}

# =======================================================================
# user_agent (public object method)
#
# Returns a LWP::UserAgent which conforms to the relevant timeouts,
# proxies, and other settings on the particular Finance::Quote object.
#
# This function is mainly intended to be used by the modules that we load,
# but it can be used by the application to directly play with the
# user-agent settings.

sub user_agent {
  my $this = shift;
  return $this->get_user_agent();
}

1;

__END__

=head1 NAME

Finance::Quote - Get stock and mutual fund quotes from various exchanges

=head1 SYNOPSIS

   use Finance::Quote;

   $q = Finance::Quote->new;
   %quotes  = $q->fetch("nasdaq", @stocks);

=head1 DESCRIPTION

This module gets stock quotes from various internet sources all over the world.
Quotes are obtained by constructing a quoter object and using the fetch method
to gather data, which is returned as a two-dimensional hash (or a reference to
such a hash, if called in a scalar context).  For example:

    $q = Finance::Quote->new;
    %info = $q->fetch("australia", "CML");
    print "The price of CML is ".$info{"CML", "price"};

The first part of the hash (eg, "CML") is referred to as the stock.
The second part (in this case, "price") is referred to as the label.

=head2 LABELS

When information about a stock is returned, the following standard labels may
be used.  Some custom-written modules may use labels not mentioned here.  If
you wish to be certain that you obtain a certain set of labels for a given
stock, you can specify that using require_labels().

    ask          Ask
    avg_vol      Average Daily Vol
    bid          Bid
    cap          Market Capitalization
    close        Previous Close
    currency     Currency code for the returned data
    date         Last Trade Date  (MM/DD/YY format)
    day_range    Day's Range
    div          Dividend per Share
    div_date     Dividend Pay Date
    div_yield    Dividend Yield
    eps          Earnings per Share
    errormsg     If success is false, this field may contain the reason why.
    ex_div       Ex-Dividend Date.
    exchange     The exchange the information was obtained from.
    high         Highest trade today
    isin         International Securities Identification Number
    isodate      ISO 8601 formatted date 
    last         Last Price
    low          Lowest trade today
    method       The module (as could be passed to fetch) which found this information.
    name         Company or Mutual Fund Name
    nav          Net Asset Value
    net          Net Change
    open         Today's Open
    p_change     Percent Change from previous day's close
    pe           P/E Ratio
    success      Did the stock successfully return information? (true/false)
    time         Last Trade Time
    type         The type of equity returned
    volume       Volume
    year_range   52-Week Range
    yield        Yield (usually 30 day avg)

If all stock lookups fail (possibly because of a failed connection) then the
empty list may be returned, or undef in a scalar context.

=head1 INSTALLATION

Please note that the Github repository is not meant for general users
of Finance::Quote for installation.

If you downloaded the Finance-Quote-N.NN.tar.gz tarball from CPAN
(N.NN is the version number, ex: Finance-Quote-1.50.tar.gz),
run the following commands:

    tar xzf Finance-Quote-1.50.tar.gz
    cd Finance-Quote-1.50.tar.gz
    perl Makefile.PL
    make
    make test
    make install

If you have the CPAN module installed:
Using cpanm (Requires App::cpanminus)

    cpanm Finance::Quote

or
Using CPAN shell

    perl -MCPAN -e shell
    install Finance::Quote

=head1 SUPPORT AND DOCUMENTATION

After installing, you can find documentation for this module with the
perldoc command.

    perldoc Finance::Quote

You can also look for information at:

=over

=item Finance::Quote GitHub project

https://github.com/finance-quote/finance-quote

=item Search CPAN

http://search.cpan.org/dist/Finance-Quote

=item The Finance::Quote home page

http://finance-quote.sourceforge.net/

=item The Finance::YahooQuote home page

http://www.padz.net/~djpadz/YahooQuote/

=item The GnuCash home page

http://www.gnucash.org/

=back

=head1 PUBLIC CLASS METHODS

Finance::Quote implements public class methods for constructing a quoter
object, getting or setting default class values, and for listing available
methods.

=head2 new

    my $q = Finance::Quote->new()
    my $q = Finance::Quote->new('-defaults')
    my $q = Finance::Quote->new('AEX', 'Fool')
    my $q = Finance::Quote->new(timeout => 30)
    my $q = Finance::Quote->new('YahooJSON', fetch_currency => 'EUR')
    my $q = Finance::Quote->new('alphavantage' => {API_KEY => '...'})
    my $q = Finance::Quote->new('IEXCloud', 'iexcloud' => {API_KEY => '...'});
    my $q = Finance::Quote->new(currency_rates => {order => ['ECB', 'Fixer'], 'fixer' => {API_KEY => '...'}});

Finance::Quote modules access a wide range of sources to provide quotes.  A
module provides one or more methods to fetch quotes. One method is usually the
name of the module in lower case. Other methods, if provided, are descriptive
names, such as 'canada', 'nasdaq', or 'nyse'.

A Finance::Quote object uses one or more methods to fetch quotes for
securities. 

C<new> constructs a Finance::Quote object and enables the caller to load only
specific modules, set parameters that control the behavior of the fetch method,
and pass method specific parameters.

=over

=item C<timeout => T> sets the web request timeout to C<T> seconds

=item C<failover => B> where C<B> is a boolean value indicating if failover in
fetch is permitted

=item C<fetch_currency => C> sets the desired currency code to C<C> for fetch
results

=item C<currency_rates => H> configures the order currency rate modules are
consulted for exchange rates and currency rate module options

=item C<required_labels => A> sets the required labels for fetch results to
array C<A>

=item C<<ModuleName>> as a string is the name of a specific
Finance::Quote::Module to load

=item C<<methodname> => H> passes hash C<H> to methodname during fetch to 
configure the method

=back

With no arguments, C<new> creates a Finance::Quote object with the default
methods.  If the environment variable FQ_LOAD_QUOTELET is set, then the
contents of FQ_LOAD_QUOTELET (split on whitespace) will be used as the argument
list.  This allows users to load their own custom modules without having to
change existing code. If any method names are passed to C<new> or the flag
'-defaults' is included in the argument list, then FQ_LOAD_QUOTELET is ignored.

When new() is passed one or more class name arguments, an object is created with
only the specified modules loaded.  If the first argument is '-defaults', then
the default modules will be loaded first, followed by any other specified
modules. Note that the FQ_LOAD_QUOTELET environment variable must begin with
'-defaults' if you wish the default modules to be loaded.

Method names correspond to the Perl module in the Finance::Quote module space.
For example, C<Finance::Quote->new('ASX')> will load the module
Finance::Quote::ASX, which provides the method "asx".

Some methods require API keys or have unique options. Passing 'method => HASH'
to new() enables the caller to provide a configuration HASH to the corresponding
method.

The key 'currency_rates' configures the Finanace::Quote currency rate
conversion.  By default, to maintain backward compatability,
Finance::Quote::CurrencyRates::AlphaVantage is used for currency conversion.
This end point requires an API key, which can either be set in the environment
or included in the configuration hash. To specify a different primary currency
conversion method or configure fallback methods, include the 'order' key, which
points to an array of Finance::Quote::CurrencyRates module names. See the
documentation for the individual Finance::Quote::CurrencyRates to learn more. 

=head2 get_default_currency_fields

    my @fields = Finance::Quote::get_default_currency_fields();

C<get_default_currency_fields> returns the standard list of fields in a quote
that are automatically converted during currency conversion. Individual modules
may override this list.

=head2 get_default_timeout
  
    my $value = Finance::Quote::get_default_timeout();

C<get_default_timeout> returns the current Finance::Quote default timeout in
seconds for web requests. Finance::Quote does not specify a default timeout,
deferring to the underlying user agent for web requests. So this function
will return undef unless C<set_default_timeout> was previously called.

=head2 set_default_timeout

    Finance::Quote::set_default_timeout(45);

C<set_default_timeout> sets the Finance::Quote default timeout to a new value.

=head2 get_methods

    my @methods = Finance::Quote::get_methods();

C<get_methods> returns the list of methods that can be passed to C<new> when
creating a quoter object and as the first argument to C<fetch>.

=head1 PUBLIC OBJECT METHODS

=head2 B_to_billions

    my $value = $q->B_to_billions("20B");

C<B_to_billions> is a utility function that expands a numeric string with a "B"
suffix to the corresponding multiple of 1000000000.

=head2 decimal_shiftup

    my $value = $q->decimal_shiftup("123.45", 1);  # returns 1234.5
    my $value = $q->decimal_shiftup("0.25", 1);    # returns 2.5

C<decimal_shiftup> moves a the decimal point in a numeric string the specified
number of places to the right.

=head2 fetch

    my %stocks  = $q->fetch("alphavantage", "IBM", "MSFT", "LNUX");
    my $hashref = $q->fetch("nasdaq", "IBM", "MSFT", "LNUX");

C<fetch> takes a method as its first argument and the remaining arguments are
treated as securities.  If the quoter C<$q> was constructed with a specific
method or methods, then only those methods are available.

When called in an array context, a hash is returned.  In a scalar context, a
reference to a hash will be returned. The keys for the returned hash are
C<{SECURITY,LABEL}>.  For the above example call, C<$stocks{"IBM","high"}> is
the high value for IBM.

$q->get_methods() returns the list of valid methods for quoter object $q. Some
methods specify a specific Finance::Quote module, such as 'alphavantage'. Other
methods are available from multiple Finance::Quote modules, such as 'nasdaq'.
The quoter failover over option determines if multiple modules are consulted
for methods such as 'nasdaq' that more than one implementation.

=head2 get_failover

    my $failover = $q->get_failover();

Failover is when the C<fetch> method attempts to retrieve quote information for
a security from alternate sources when the requested method fails.
C<get_failover> returns a boolean value indicating if the quoter object will
use failover or not.

=head2 set_failover

    $q->set_failover(False);

C<set_failover> sets the failover flag on the quoter object. 

=head2 get_fetch_currency

    my $currency = $q->get_fetch_currency();

C<get_fetch_currency> returns either the desired currency code for the quoter
object or undef if no target currency was set during construction or with the
C<set_fetch_currency> function.

=head2 set_fetch_currency

    $q->set_fetch_currency("FRF");  # Get results in French Francs.

C<set_fetch_currency> method is used to request that all information be
returned in the specified currency.  Note that this increases the chance
stock-lookup failure, as remote requests must be made to fetch both the stock
information and the currency rates.  In order to improve reliability and speed
performance, currency conversion rates are cached and are assumed not to change
for the duration of the Finance::Quote object.

See the introduction to this page for information on how to configure the
souce of currency conversion rates.

=head2 get_required_labels

    my @labels = $q->get_required_labels();

C<get_required_labels> returns the list of labels that must be populated for a
security quote to be considered valid and returned by C<fetch>.

=head2 set_required_labels

    my $labels = ['close', 'isodate', 'last'];
    $q->set_required_labels($labels);

C<set_required_labels> updates the list of required labels for the quoter object.

=head2 get_timeout

    my $timeout = $q->get_timeout();

C<get_timeout> returns the timeout in seconds the quoter object is using for
web requests.

=head2 set_timeout

    $q->set_timeout(45);

C<set_timeout> updated teh timeout in seconds for the quoter object.

=head2 store_date

    $quoter->store_date(\%info, $stocks, {eurodate => '06/11/2020'});

C<store_date> is used by modules to consistent store date information about 
securities. Given the various pieces of a date, this function figures out how to
construct a ISO date (yyyy-mm-dd) and US date (mm/dd/yyyy) and stores those
values in C<%info> for security C<$stock>.

=head2 get_user_agent

    my $ua = $q->get_user_agent();

C<get_user_agent> returns the LWP::UserAgent the quoter object is using for web
requests.

=head2 isoTime

    $q->isoTime("11:39PM");    # returns "23:39"
    $q->isoTime("9:10 AM");    # returns "09:10"

C<isoTime> returns an ISO formatted time.

=head1 PUBLIC CLASS OR OBJECT METHODS

The following methods are available as class methods, but can also be called
from Finance::Quote objects.

=head2 scale_field

    my $value = Finance::Quote->scale_field('1023', '0.01')

C<scale_field> is a utility function that scales the first argument by the
second argument.  In the above example, C<value> is C<'10.23'>.

=head2 currency

    my $value = $q->currency('15.95 USD', 'AUD');
    my $value = Finance::Quote->currency('23.45 EUR', 'RUB');

C<currency> converts a value with a currency code suffix to another currency
using the current exchange rate as determined by the
Finance::Quote::CurrencyRates method or methods configured for the quoter $q.
When called as a class method, only Finance::Quote::AlphaVantage is used, which
requires an API key. See the introduction for information on configuring
currency rate conversions and see Finance::Quote::CurrencyRates::AlphaVantage
for information about the API key.

=head2 currency_lookup

    my $currency = $quoter->currency_lookup();
    my $currency = $quoter->currency_lookup( name => "Caribbean");
    my $currency = $quoter->currency_loopup( country => qw/denmark/i );
    my $currency = $q->currency_lookup(country => qr/united states/i, number => 840);

C<currency_lookup> takes zero or more constraints and filters the list of
currencies known to Finance::Quote. It returns a hash reference where the keys
are ISO currency codes and the values are hash references containing metadata
about the currency. 

A constraint is a key name and either  a scalar or regular expression.  A
currency satisfies the constraint if its metadata hash contains the constraint
key and the value of that metadata field matches the regular expression or
contains the constraint value as a substring.  If the metadata field is an
array, then it satisfies the constraint if any value in the array satisfies the
constraint.

=head2 parse_csv

    my @list = Finance::Quote::parse_csv($string);

C<parse_csv> is a utility function for spliting a comma seperated value string
into a list of terms, treating double-quoted strings that contain commas as a
single value.

=head2 parse_csv_semicolon

    my @list = Finance::Quote::parse_csv_semicolon($string);

C<parse_csv> is a utility function for spliting a semicolon seperated value string
into a list of terms, treating double-quoted strings that contain semicolons as a
single value.

=head1 LEGACY METHODS

=head2 default_currency_fields

Replaced with get_default_currency_fields().

=head2 sources

Replaced with get_methods().

=head2 failover

Replaced with get_failover() and set_failover().

=head2 require_labels

Replaced with get_required_labels() and set_required_labels().

=head2 user_agent

Replaced with get_user_agent().

=head2 set_currency

Replaced with get_fetch_currency() and set_fetch_currency().

=head1 ENVIRONMENT

Finance::Quote respects all environment that your installed version of
LWP::UserAgent respects.  Most importantly, it respects the http_proxy
environment variable.

=head1 BUGS

The caller cannot control the fetch failover order.

The two-dimensional hash is a somewhat unwieldly method of passing around
information when compared to references

=head1 COPYRIGHT & LICENSE

 Copyright 1998, Dj Padzensky
 Copyright 1998, 1999 Linas Vepstas
 Copyright 2000, Yannick LE NY (update for Yahoo Europe and YahooQuote)
 Copyright 2000-2001, Paul Fenwick (updates for ASX, maintenance and release)
 Copyright 2000-2001, Brent Neal (update for TIAA-CREF)
 Copyright 2000 Volker Stuerzl (DWS)
 Copyright 2001 Rob Sessink (AEX support)
 Copyright 2001 Leigh Wedding (ASX updates)
 Copyright 2001 Tobias Vancura (Fool support)
 Copyright 2001 James Treacy (TD Waterhouse support)
 Copyright 2008 Erik Colson (isoTime)

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

Currency information fetched through this module is bound by the terms and
conditons of the data source.

Other copyrights and conditions may apply to data fetched through this module.
Please refer to the sub-modules for further information.

=head1 AUTHORS

  Dj Padzensky <djpadz@padz.net>, PadzNet, Inc.
  Linas Vepstas <linas@linas.org>
  Yannick LE NY <y-le-ny@ifrance.com>
  Paul Fenwick <pjf@cpan.org>
  Brent Neal <brentn@users.sourceforge.net>
  Volker Stuerzl <volker.stuerzl@gmx.de>
  Keith Refson <Keith.Refson#earth.ox.ac.uk>
  Rob Sessink <rob_ses@users.sourceforge.net>
  Leigh Wedding <leigh.wedding@telstra.com>
  Tobias Vancura <tvancura@altavista.net>
  James Treacy <treacy@debian.org>
  Bradley Dean <bjdean@bjdean.id.au>
  Erik Colson <eco@ecocode.net>

The Finance::Quote home page can be found at
http://finance-quote.sourceforge.net/

The Finance::YahooQuote home page can be found at
http://www.padz.net/~djpadz/YahooQuote/

The GnuCash home page can be found at
http://www.gnucash.org/

=head1 SEE ALSO

Finance::Quote::CurrencyRates::AlphaVantage,
Finance::Quote::CurrencyRates::ECB,
Finance::Quote::CurrencyRates::Fixer,
Finance::Quote::CurrencyRates::OpenExchange,
Finance::Quote::AEX,
Finance::Quote::ASEGR,
Finance::Quote::ASX,
Finance::Quote::Bloomberg,
Finance::Quote::BSEIndia,
Finance::Quote::Bourso,
Finance::Quote::CSE,
Finance::Quote::Cdnfundlibrary,
Finance::Quote::Comdirect,
Financ::Quote::Currencies,
Finance::Quote::DWS,
Finance::Quote::Deka,
Finance::Quote::FTfunds,
Finance::Quote::Fidelity,
Finance::Quote::Finanzpartner,
Finance::Quote::Fondsweb,
Finance::Quote::Fool,
Finance::Quote::Fundata
Finance::Quote::GoldMoney,
Finance::Quote::HU,
Finance::Quote::IEXCloud,
Finance::Quote::IndiaMutual,
Finance::Quote::MStaruk,
Finance::Quote::MorningstarAU,
Finance::Quote::NSEIndia,
Finance::Quote::NZX,
Finance::Quote::OnVista,
Finance::Quote::Oslobors,
Finance::Quote::SEB,
Finance::Quote::SIX,
Finance::Quote::Tradeville,
Finance::Quote::TSP,
Finance::Quote::TMX,
Finance::Quote::Tiaacref,
Finance::Quote::Troweprice,
Finance::Quote::USFedBonds,
Finance::Quote::Union,
Finance::Quote::YahooJSON,
Finance::Quote::ZA

You should have received the Finance::Quote hacker's guide with this package.
Please read it if you are interested in adding extra methods to this package.
The latest hacker's guide can also be found on GitHub at
https://github.com/finance-quote/finance-quote/blob/master/Documentation/Hackers-Guide

=cut
