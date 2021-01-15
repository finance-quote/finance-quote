# NAME

Finance::Quote - Get stock and mutual fund quotes from various exchanges

# SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;
    %quotes  = $q->fetch("nasdaq", @stocks);

# DESCRIPTION

This module gets stock quotes from various internet sources all over the world.
Quotes are obtained by constructing a quoter object and using the fetch method
to gather data, which is returned as a two-dimensional hash (or a reference to
such a hash, if called in a scalar context).  For example:

    $q = Finance::Quote->new;
    %info = $q->fetch("australia", "CML");
    print "The price of CML is ".$info{"CML", "price"};

The first part of the hash (eg, "CML") is referred to as the stock.
The second part (in this case, "price") is referred to as the label.

## LABELS

When information about a stock is returned, the following standard labels may
be used.  Some custom-written modules may use labels not mentioned here.  If
you wish to be certain that you obtain a certain set of labels for a given
stock, you can specify that using require\_labels().

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

# INSTALLATION

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

# SUPPORT AND DOCUMENTATION

After installing, you can find documentation for this module with the
perldoc command.

    perldoc Finance::Quote

You can also look for information at:

- Finance::Quote GitHub project

    https://github.com/finance-quote/finance-quote

- Search CPAN

    http://search.cpan.org/dist/Finance-Quote

- The Finance::Quote home page

    http://finance-quote.sourceforge.net/

- The Finance::YahooQuote home page

    http://www.padz.net/~djpadz/YahooQuote/

- The GnuCash home page

    http://www.gnucash.org/

# PUBLIC CLASS METHODS

Finance::Quote implements public class methods for constructing a quoter
object, getting or setting default class values, and for listing available
methods.

## new

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

`new` constructs a Finance::Quote object and enables the caller to load only
specific modules, set parameters that control the behavior of the fetch method,
and pass method specific parameters.

- `timeout =` T> sets the web request timeout to `T` seconds
- `failover =` B> where `B` is a boolean value indicating if failover in
fetch is permitted
- `fetch_currency =` C> sets the desired currency code to `C` for fetch
results
- `currency_rates =` H> configures the order currency rate modules are
consulted for exchange rates and currency rate module options
- `required_labels =` A> sets the required labels for fetch results to
array `A`
- `<ModuleName`> as a string is the name of a specific
Finance::Quote::Module to load
- `<methodname` => H> passes hash `H` to methodname during fetch to 
configure the method

With no arguments, `new` creates a Finance::Quote object with the default
methods.  If the environment variable FQ\_LOAD\_QUOTELET is set, then the
contents of FQ\_LOAD\_QUOTELET (split on whitespace) will be used as the argument
list.  This allows users to load their own custom modules without having to
change existing code. If any method names are passed to `new` or the flag
'-defaults' is included in the argument list, then FQ\_LOAD\_QUOTELET is ignored.

When new() is passed one or more class name arguments, an object is created with
only the specified modules loaded.  If the first argument is '-defaults', then
the default modules will be loaded first, followed by any other specified
modules. Note that the FQ\_LOAD\_QUOTELET environment variable must begin with
'-defaults' if you wish the default modules to be loaded.

Method names correspond to the Perl module in the Finance::Quote module space.
For example, `Finance::Quote-`new('ASX')> will load the module
Finance::Quote::ASX, which provides the method "asx".

Some methods require API keys or have unique options. Passing 'method => HASH'
to new() enables the caller to provide a configuration HASH to the corresponding
method.

The key 'currency\_rates' configures the Finanace::Quote currency rate
conversion.  By default, to maintain backward compatability,
Finance::Quote::CurrencyRates::AlphaVantage is used for currency conversion.
This end point requires an API key, which can either be set in the environment
or included in the configuration hash. To specify a different primary currency
conversion method or configure fallback methods, include the 'order' key, which
points to an array of Finance::Quote::CurrencyRates module names. See the
documentation for the individual Finance::Quote::CurrencyRates to learn more. 

## get\_default\_currency\_fields

    my @fields = Finance::Quote::get_default_currency_fields();

`get_default_currency_fields` returns the standard list of fields in a quote
that are automatically converted during currency conversion. Individual modules
may override this list.

## get\_default\_timeout

    my $value = Finance::Quote::get_default_timeout();

`get_default_timeout` returns the current Finance::Quote default timeout in
seconds for web requests. Finance::Quote does not specify a default timeout,
deferring to the underlying user agent for web requests. So this function
will return undef unless `set_default_timeout` was previously called.

## set\_default\_timeout

    Finance::Quote::set_default_timeout(45);

`set_default_timeout` sets the Finance::Quote default timeout to a new value.

## get\_methods

    my @methods = Finance::Quote::get_methods();

`get_methods` returns the list of methods that can be passed to `new` when
creating a quoter object and as the first argument to `fetch`.

# PUBLIC OBJECT METHODS

## B\_to\_billions

    my $value = $q->B_to_billions("20B");

`B_to_billions` is a utility function that expands a numeric string with a "B"
suffix to the corresponding multiple of 1000000000.

## decimal\_shiftup

    my $value = $q->decimal_shiftup("123.45", 1);  # returns 1234.5
    my $value = $q->decimal_shiftup("0.25", 1);    # returns 2.5

`decimal_shiftup` moves a the decimal point in a numeric string the specified
number of places to the right.

## fetch

    my %stocks  = $q->fetch("alphavantage", "IBM", "MSFT", "LNUX");
    my $hashref = $q->fetch("nasdaq", "IBM", "MSFT", "LNUX");

`fetch` takes a method as its first argument and the remaining arguments are
treated as securities.  If the quoter `$q` was constructed with a specific
method or methods, then only those methods are available.

When called in an array context, a hash is returned.  In a scalar context, a
reference to a hash will be returned. The keys for the returned hash are
`{SECURITY,LABEL}`.  For the above example call, `$stocks{"IBM","high"}` is
the high value for IBM.

$q->get\_methods() returns the list of valid methods for quoter object $q. Some
methods specify a specific Finance::Quote module, such as 'alphavantage'. Other
methods are available from multiple Finance::Quote modules, such as 'nasdaq'.
The quoter failover over option determines if multiple modules are consulted
for methods such as 'nasdaq' that more than one implementation.

## get\_failover

    my $failover = $q->get_failover();

Failover is when the `fetch` method attempts to retrieve quote information for
a security from alternate sources when the requested method fails.
`get_failover` returns a boolean value indicating if the quoter object will
use failover or not.

## set\_failover

    $q->set_failover(False);

`set_failover` sets the failover flag on the quoter object. 

## get\_fetch\_currency

    my $currency = $q->get_fetch_currency();

`get_fetch_currency` returns either the desired currency code for the quoter
object or undef if no target currency was set during construction or with the
`set_fetch_currency` function.

## set\_fetch\_currency

    $q->set_fetch_currency("FRF");  # Get results in French Francs.

`set_fetch_currency` method is used to request that all information be
returned in the specified currency.  Note that this increases the chance
stock-lookup failure, as remote requests must be made to fetch both the stock
information and the currency rates.  In order to improve reliability and speed
performance, currency conversion rates are cached and are assumed not to change
for the duration of the Finance::Quote object.

See the introduction to this page for information on how to configure the
souce of currency conversion rates.

## get\_required\_labels

    my @labels = $q->get_required_labels();

`get_required_labels` returns the list of labels that must be populated for a
security quote to be considered valid and returned by `fetch`.

## set\_required\_labels

    my $labels = ['close', 'isodate', 'last'];
    $q->set_required_labels($labels);

`set_required_labels` updates the list of required labels for the quoter object.

## get\_timeout

    my $timeout = $q->get_timeout();

`get_timeout` returns the timeout in seconds the quoter object is using for
web requests.

## set\_timeout

    $q->set_timeout(45);

`set_timeout` updated teh timeout in seconds for the quoter object.

## store\_date

    $quoter->store_date(\%info, $stocks, {eurodate => '06/11/2020'});

`store_date` is used by modules to consistent store date information about 
securities. Given the various pieces of a date, this function figures out how to
construct a ISO date (yyyy-mm-dd) and US date (mm/dd/yyyy) and stores those
values in `%info` for security `$stock`.

## get\_user\_agent

    my $ua = $q->get_user_agent();

`get_user_agent` returns the LWP::UserAgent the quoter object is using for web
requests.

## isoTime

    $q->isoTime("11:39PM");    # returns "23:39"
    $q->isoTime("9:10 AM");    # returns "09:10"

`isoTime` returns an ISO formatted time.

# PUBLIC CLASS OR OBJECT METHODS

The following methods are available as class methods, but can also be called
from Finance::Quote objects.

## scale\_field

    my $value = Finance::Quote->scale_field('1023', '0.01')

`scale_field` is a utility function that scales the first argument by the
second argument.  In the above example, `value` is `'10.23'`.

## currency

    my $value = $q->currency('15.95 USD', 'AUD');
    my $value = Finance::Quote->currency('23.45 EUR', 'RUB');

`currency` converts a value with a currency code suffix to another currency
using the current exchange rate as determined by the
Finance::Quote::CurrencyRates method or methods configured for the quoter $q.
When called as a class method, only Finance::Quote::AlphaVantage is used, which
requires an API key. See the introduction for information on configuring
currency rate conversions and see Finance::Quote::CurrencyRates::AlphaVantage
for information about the API key.

## currency\_lookup

    my $currency = $quoter->currency_lookup();
    my $currency = $quoter->currency_lookup( name => "Caribbean");
    my $currency = $quoter->currency_loopup( country => qw/denmark/i );
    my $currency = $q->currency_lookup(country => qr/united states/i, number => 840);

`currency_lookup` takes zero or more constraints and filters the list of
currencies known to Finance::Quote. It returns a hash reference where the keys
are ISO currency codes and the values are hash references containing metadata
about the currency. 

A constraint is a key name and either  a scalar or regular expression.  A
currency satisfies the constraint if its metadata hash contains the constraint
key and the value of that metadata field matches the regular expression or
contains the constraint value as a substring.  If the metadata field is an
array, then it satisfies the constraint if any value in the array satisfies the
constraint.

## parse\_csv

    my @list = Finance::Quote::parse_csv($string);

`parse_csv` is a utility function for spliting a comma seperated value string
into a list of terms, treating double-quoted strings that contain commas as a
single value.

## parse\_csv\_semicolon

    my @list = Finance::Quote::parse_csv_semicolon($string);

`parse_csv` is a utility function for spliting a semicolon seperated value string
into a list of terms, treating double-quoted strings that contain semicolons as a
single value.

# LEGACY METHODS

## default\_currency\_fields

Replaced with get\_default\_currency\_fields().

## sources

Replaced with get\_methods().

## failover

Replaced with get\_failover() and set\_failover().

## require\_labels

Replaced with get\_required\_labels() and set\_required\_labels().

## user\_agent

Replaced with get\_user\_agent().

## set\_currency

Replaced with get\_fetch\_currency() and set\_fetch\_currency().

# ENVIRONMENT

Finance::Quote respects all environment that your installed version of
LWP::UserAgent respects.  Most importantly, it respects the http\_proxy
environment variable.

# BUGS

The caller cannot control the fetch failover order.

The two-dimensional hash is a somewhat unwieldly method of passing around
information when compared to references

# COPYRIGHT & LICENSE

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

# AUTHORS

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

# SEE ALSO

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
