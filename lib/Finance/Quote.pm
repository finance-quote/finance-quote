#!/usr/bin/perl -w
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@schools.net.au>
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
#    Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
#    02111-1307, USA
#
#
# This code derived from Padzensky's work on package Finance::YahooQuote,
# but extends its capabilites to encompas a greater number of data sources.
#
# This code was developed as part of GnuCash <http://www.gnucash.org/>

package Finance::Quote;
require 5.004;

use strict;
use Exporter ();
use Carp;
use LWP::UserAgent;
use HTTP::Request::Common;

use vars qw/@ISA @EXPORT @EXPORT_OK @EXPORT_TAGS
            $VERSION $TIMEOUT %MODULES %METHODS $AUTOLOAD/;

@ISA    = qw/Exporter/;
@EXPORT = ();
@EXPORT_OK = qw/yahoo yahoo_europe fidelity troweprice asx tiaacref/;
@EXPORT_TAGS = ( all => [@EXPORT_OK]);

$VERSION = '0.19';

# Autoload method for obsolete methods.  This also allows people to
# call methods that objects export without having to go through fetch.

sub AUTOLOAD {
	my $method = $AUTOLOAD;
	$method =~ s/.*:://;

	# Force the dummy object (and hence default methods) to be loaded.
	_dummy();

	# If the method we want is in %METHODS, then set up an appropriate
	# subroutine for it next time.

	if (exists($METHODS{$method})) {
		eval qq[sub $method {
			_dummy()->fetch("$method",\@_); 
		}];
		carp $@ if $@;
		no strict 'refs';	# So we can use &$method
		return &$method(@_);
	}

	carp "$AUTOLOAD does not refer to a known method.";
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

			# Have to use an eval here because perl doesn't
			# like to use strings.
			eval "use $modpath;";
			carp $@ if $@;
			$MODULES{$modpath} = 1;

			# Methodhash will continue method-name, function ref
			# pairs.
			my %methodhash = $modpath->methods;

			foreach my $method (keys %methodhash) {
				push (@{$METHODS{$method}},$methodhash{$method});
			}
		}
	}
}

# =======================================================================
# new (public class method)
#
# Returns a new Finance::Quote object.  If methods are asked for, then
# it will load the relevant modules.  With no arguments, this function
# loads a default set of methods.

sub new {
	my $self = shift;
	my $class = ref($self) || $self;

	my $this = {};
	bless $this, $class;

	my @modules = ();

	# If we get an empty new(), or one starting with -defaults,
	# then load up the default methods.
	if (!scalar(@_) or $_[0] eq "-defaults") {
		shift if (scalar(@_));
		# Default modules
		 @modules = qw/Yahoo::USA Yahoo::Europe Fidelity 
			       Troweprice ASX Tiaacref/;
	}

	$this->_load_modules(@modules,@_);

	$this->{TIMEOUT} = $TIMEOUT if defined($TIMEOUT);
	$this->{FAILOVER} = 1;

	return $this;
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

# =======================================================================
# Timeout code.  If called on a particular object, then it sets
# the timout for that object only.  If called as a class method
# (or as Finance::Quote::timeout) then it sets the default timeout
# for all new objects that will be created.

sub timeout {
	if (@_ == 1 or !ref($_[0])) {	# Direct or class call.
		return $TIMEOUT = $_[0];
	}
	
	# Otherwise we were called through an object.  Yay.
	# Set the timeout in this object only.
	my $this = shift;
	return $this->{TIMEOUT} = shift;
}

# =======================================================================
# failover (public object method)
#
# This sets/gets whether or not it's acceptable to use failover techniques.

sub failover {
	my $this = shift;
	my $value = shift;
        return $this->{FAILOVER} = $value if (defined($value));
	return $this->{FAILOVER};
}

# =======================================================================
# Fetch is a wonderful generic fetcher.  It takes a method and stuff to
# fetch.  It's a nicer interface for when you have a list of stocks with
# different sources which you wish to deal with.
sub fetch {
	my $this = shift if ref ($_[0]);
	
	$this ||= _dummy();
	
	my $method = lc(shift);
	my @stocks = @_;

	unless (exists $METHODS{$method}) {
		carp "Undefined fetch-method $method passed to ".
		     "Finance::Quote::fetch";
		return undef;
	}

	# Failover code.  This steps through all availabe methods while
	# we still have failed stocks to look-up.

	if ($this->{FAILOVER}) {
		my %returnhash = ();

		foreach my $funcref (@{$METHODS{$method}}) {
			my @failed_stocks = ();
			%returnhash = (%returnhash,&$funcref($this,@stocks));

			foreach my $stock (@stocks) {
				push(@failed_stocks,$stock)
					unless ($returnhash{$stock,"success"});
			}
			last unless @failed_stocks;
			@stocks = @failed_stocks;
		}

		return %returnhash;
	}

	# No failover?  Okay, we'll just use the first method available
	# then.

	my $funcref = @{$METHODS{$method}}[0];
	return &$funcref($this,@stocks);
}

# =======================================================================
# user_agent (public object method)
#
# Returns a LWP::UserAgent which conforms to the relevant timeouts,
# proxies, and other settings on the particular Finance::Quote object.
#
# This function is mainly intended to be used by the modules that we load.

sub user_agent {
	my $this = shift;

	my $ua = LWP::UserAgent->new;
	$ua->timeout($this->{TIMEOUT}) if defined($this->{TIMEOUT});
	$ua->env_proxy;

	return $ua;
}

# =======================================================================
# parse_csv (public object method)
#
# Grabbed from the Perl Cookbook. Parsing csv isn't as simple as you thought!
#
sub parse_csv
{
    shift if (ref $_[0]);	# Shift off the object if we have one.
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

# Dummy destroy function to avoid AUTOLOAD catching it.
sub DESTROY { return; }

1;

__END__

=head1 NAME

Finance::Quote - Get stock and mutual fund quotes from various exchanges

=head1 SYNOPSIS

 use Finance::Quote;
 my $q = Finance::Quote->new;          # New Finance::Quote object.
 $q->timeout(60);		       # Timeout max of 60 seconds
 %quotes = $q->yahoo(@symbols);	       # NYSE quotes 
 %quotes = $q->yahoo_europe(@symbols); # Europe quotes
 %quotes = $q->fidelity(@symbols);     # Fidelity Investments Quotes
 %quotes = $q->troweprice();           # Quotes from T. Rowe Price
 %quotes = $q->tiaacref(@symbols);     # Annuities from TIAA-CREF
 %quotes = $q->asx(@symbols);          # Australian quotes from ASX.
 %quotes = $q->fetch("asx",@symbols);  # Same as above, different syntax.
 print ("the last price was ", $quotes{"IBM", "last"} );

=head1 DESCRIPTION

This module gets stock quotes from various internet sources, including
Yahoo!  Finance, Fidelity Investments, and the Australian Stock Exchange.
The functions will return a quote for each of the stock symbols passed to
it.  The return value of each of the routines is a hash, which may include
one or more of the following elements:

    name         Company or Mutual Fund Name
    last         Last Price
    high	 Highest trade today
    low		 Lowest trade today
    date         Last Trade Date  (MM/DD/YY format)
    time         Last Trade Time
    net          Net Change
    p_change     Percent Change from previous day's close
    volume       Volume
    avg_vol      Average Daily Vol
    bid          Bid
    ask          Ask
    close        Previous Close
    open         Today's Open
    day_range    Day's Range
    year_range   52-Week Range
    eps          Earnings per Share
    pe           P/E Ratio
    div_date     Dividend Pay Date
    div          Dividend per Share
    div_yield    Dividend Yield
    cap          Market Capitalization
    ex_div	 Ex-Dividend Date.
    nav          Net Asset Value
    yield        Yield (usually 30 day avg)
    success	 Did the stock successfully return information? (true/false)
    errormsg	 If success is false, this field may contain the reason why.

    (Elements which are not yet implemented have no key associated
     with them.  Not all methods return all keys at all times.)

If all stock lookups fail (possibly because of a failed connection) then
`undef' may be returned.

You may optionally override the default LWP timeout of 180 seconds by setting
$quote->timeout() or Finance::Quote::timeout() to your preferred value.

Note that prices from the Australian Stock Exchange (ASX) are in
Australian Dollars.  Prices from Yahoo! Europe are in Euros.  All other
prices are in US Dollars.

=head2 troweprice

The troweprice() function ignores any arguments passed to it.  Instead it
returns all funds managed by T.RowePrice.

=head2 tiaacref

For TIAA and CREF Annuities, you must use TIAA-CREF's pseudosymbols. These
are as follows:

    Stock:				CREFstok
    Money Market:			CREFmony
    Equity Index:			CREFequi
    Inflation-Linked Bond:		CREFinfb
    Bond Market:			CREFbond
    TIAA Real Estate:			TIAAreal
    Social Choice:			CREFsoci
    Teachers PA Stock Index:		TIAAsndx
    Global Equities:			CREFglob
    Teachers PA Select Stock:		TIAAsele
    Growth:				CREFgrow

=head2 FETCH

    my %stocks = $q->fetch("nasdaq","IBM","MSFT");

A new function, fetch(), provides a more generic and easy-to-use interface
to the library.  It takes a source as the first argument, and then a list
of ticker-symbols to obtain from that source.  fetch() will understand the
case-insensitive sources "nasdaq", "nyse" and "europe", and map them to
the yahoo or yahoo_europe methods appropriately.

=head1 ENVIRONMENT

Finance::Quote respects all environment that your installed
version of LWP::UserAgent respects.  Most importantly, it
respects the http_proxy environment variable.

=head1 FAQ

If there's one question I get asked over and over again, it's how did I
figure out the format string for Yahoo! quotes?  Having typed the answer in
innumerable emails, I figure sticking it directly into the man page might
help save my fingers a bit...

If you have a My Yahoo! (http://my.yahoo.com) account, go to the
following URL:

    http://edit.my.yahoo.com/config/edit_pfview?.vk=v1

Viewing the source of this page, you'll come across the section that
defines the menus that let you select which elements go into a
particular view.  The <option> values are the strings that pick up
the information described in the menu item.  For example, Symbol
refers to the string "s" and name refers to the string "l".  Using
"sl" as the format string, we would get the symbol followed by the
name of the security.

If you have questions regarding this, play around with $YAHOO_URL, changing
the value of the f parameter.

=head1 BUGS

Not all functions return an errormsg when a failure results.

Not everything checks for errors as well as they could.

There is no way to add extra aliases to the fetch list.

There is no good documentation on which functions return what fields.

This documentation is getting a little long and cumbersome.  It should
be broken up into more logical sections.

=head1 COPYRIGHT

 Copyright 1998, Dj Padzensky
 Copyright 1998, 1999 Linas Vepstas
 Copyright 2000, Yannick LE NY (update for Yahoo Europe and YahooQuote)
 Copyright 2000, Paul Fenwick (update for ASX)
 Copyright 2000, Brent Neal (update for TIAA-CREF)

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or (at
your option) any later version.

The information that you obtain with this library may be copyrighted
by Yahoo! Inc., and is governed by their usage license. See
http://www.yahoo.com/docs/info/gen_disclaimer.html for more
information.

The information that you obtain with this library may be copyrighted
by the ASX, and is governed by its usage license.  See
http://www3.asx.com.au/Fdis.htm for more information.

The information that you obtain with this library may be copyrighted
by TIAA-CREF, and is governed by its usage license.

Other copyrights and conditions may apply to data fetched through this
module.

=head1 AUTHORS

  Dj Padzensky (C<djpadz@padz.net>), PadzNet, Inc.
  Linas Vepstas (C<linas@linas.org>)
  Yannick LE NY (C<y-le-ny@ifrance.com>)
  Paul Fenwick (C<pjf@schools.net.au>)
  Brent Neal (C<brentn@users.sourceforge.net>)

The Finance::Quote home page can be found at
http://finance-quote.sourceforge.net/

The Finance::YahooQuote home page can be found at
http://www.padz.net/~djpadz/YahooQuote/

The GnuCash home page can be found at
http://www.gnucash.org/

=cut
