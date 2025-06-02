#!/usr/bin/perl -w
#
#    vi: set ts=2 sw=2 noai ic showmode showmatch:  
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
    CurrencyFreaks
    ECB
    FinanceAPI
    Fixer
    OpenExchange
    YahooJSON
/;

@MODULES = qw/
    AEX
    ASEGR
    ASX
    AlphaVantage
    BSEIndia
    Bloomberg
    BorsaItaliana
    Bourso
    BVB
    CSE
    CMBChina
    Comdirect
    Consorsbank
    Currencies
    Deka
    FinanceAPI
    Finanzpartner
    Fondsweb
    Fool
    FTfunds
    GoldMoney
    GoogleWeb
    IndiaMutual
    MarketWatch
    MorningstarCH
    MorningstarJP
    MorningstarUK
    NSEIndia
    NZX
    OnVista
    SIX
    Sinvestor
    StockData
    Stooq
    TesouroDireto
    Tiaacref
    TMX
    Tradegate
    TreasuryDirect
    Troweprice
    TSP
    TwelveData
    Union
    XETRA
    YahooJSON
    YahooWeb
    ZA
/;

@ISA    = qw/Exporter/;
@EXPORT = ();
@EXPORT_OK = qw/troweprice asx tiaacref
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
              { name => $module,
              modpath => $modpath,
              function => $methodhash{$method},
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

# return hash:
#
#  quote_methods => hash of
#      method_name => array of module names
#  quote_modules => hash of
#      module_name => array of parameters
#  currency_modules => hash of
#      module_name =>  array of parameters
#
# { 
#    'quote_methods' => {'group' => ['module', 'module'], ...},
#    'quote_modules' => {'abc' => ['API_KEY'], ...},
#    'currency_modules' => {'xyz' => [], 'lmn' => ['USER_NAME', 'API_KEY']},
# } 

sub get_features {
  # Create a dummy object to ensure METHODS is populated
  my $t = Finance::Quote->new(currency_rates => {order => \@CURRENCY_RATES_MODULES});
  my $baseclass = ref $t;

  my %feature = (
    'quote_methods' => {map {$_, [map {$_->{name}} @{$METHODS{$_}}]} keys %METHODS},
    'quote_modules' => {map {$_, []} @MODULES},
    'currency_modules' => {map {$_, []} @CURRENCY_RATES_MODULES},
  );

  my %mods = ('quote_modules' => $baseclass,
              'currency_modules' => "${baseclass}::CurrencyRates");

  while (my ($field, $base) = each %mods) {
    foreach my $name (keys %{$feature{$field}}) {
      my $modpath = "${base}::${name}";

      if ($modpath->can("parameters")) {
        push (@{$feature{$field}->{$name}}, $modpath->parameters());
      }
    }
  }

  return %feature;
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

  # Check for FQ_CURRENCY - preferred currency module
  # Set to AlphaVantage if not set or not in @CURRENCY_RATES_MODULES
  my $CURRENCY_MODULE;
  if (!$ENV{FQ_CURRENCY}) {
    $CURRENCY_MODULE='AlphaVantage';
  } else {
    if ( grep( /^$ENV{FQ_CURRENCY}$/, @CURRENCY_RATES_MODULES ) ) {
      $CURRENCY_MODULE=$ENV{FQ_CURRENCY}
    } else {
      $CURRENCY_MODULE='AlphaVantage';
    }
  }

  # Default values
  $this->{FAILOVER}       = 1;
  $this->{REQUIRED}       = [];
  $this->{TIMEOUT}        = $TIMEOUT if defined($TIMEOUT);
  $this->{currency_rates} = {order => [$CURRENCY_MODULE]};

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
    if ($load_modules[0] eq '-defaults') {
      shift @load_modules;
      push(@load_modules, @MODULES);
    }
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

  {
    no strict 'vars';
    our $VERSION = '0.00' unless defined $VERSION;
    unless ($ENV{"FQ_NOCOUNT"}) {
      # Temporary Counting - not concerned about return code
      my $COUNT_URL =
        'http://www.panix.com/~hd-fxsts/finance-quote.html?' . $VERSION . '&' . $method;
      my $count_ua = LWP::UserAgent->new(timeout => 10);
      my $count_response = $count_ua->head($COUNT_URL);

      ### COUNT_URL: $COUNT_URL
      ### Code: $count_response->code
    }
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
  if ($timeString=~m/^(\d+)[\.:UH](\d+) *(AM|am|PM|pm)?/) {
    my ($hours,$mins)= ($1-0,$2-0) ;
    $hours-=12 if ($hours==12 && $3 && ($3 =~ /AM/i));
    $hours+=12 if ($3 && ($3 =~ /PM/i) && ($hours != 12));
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

      ### format: printf STDERR "usdate %s -> Day %d, Month %s, Year %d\n", $piecesref->{usdate}, $day, $month, $year
    }

    if ((defined $piecesref->{eurodate}) && ($piecesref->{eurodate})) {
        ($day, $month, $year) = ($piecesref->{eurodate} =~ /(\d+)\W+(\w+)\W+(\d+)/);
      $year += 2000 if $year < 100;
      $year_specified = 1;

      ### format: printf STDERR "eurodate %s -> Day %d, Month %s, Year %d\n", $piecesref->{eurodate}, $day, $month, $year
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

    ### format: printf STDERR "Final Year-Month-Day -> %04d-%02d-%02d\n", $year, $month, $day

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