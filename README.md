# NAME

Finance::Quote - Get stock and mutual fund quotes from various exchanges

# SYNOPSIS

    use Finance::Quote;
    $q = Finance::Quote->new;

    $q->timeout(60);

    $conversion_rate = $q->currency("AUD", "USD");
    $q->set_currency("EUR");  # Return all info in Euros.

    $q->require_labels(qw/price date high low volume/);

    $q->failover(1); # Set failover support (on by default).

    %quotes  = $q->fetch("nasdaq", @stocks);
    $hashref = $q->fetch("nyse", @stocks);

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

    name         Company or Mutual Fund Name
    last         Last Price
    high         Highest trade today
    low          Lowest trade today
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
    ex_div       Ex-Dividend Date.
    nav          Net Asset Value
    yield        Yield (usually 30 day avg)
    exchange     The exchange the information was obtained from.
    success      Did the stock successfully return information? (true/false)
    errormsg     If success is false, this field may contain the reason why.
    method       The module (as could be passed to fetch) which found this
                 information.
    type         The type of equity returned

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

Finance::Quote has public class methods to construct a quoter object, get or
set default class values, and one helper function.

## NEW

    my $q = Finance::Quote->new()
    my $q = Finance::Quote->new('-defaults')
    my $q = Finance::Quote->new('AEX', 'Fool')
    my $q = Finance::Quote->new(timeout => 30)
    my $q = Finance::Quote->new('YahooJSON', fetch_currency => 'EUR')
    my $q = Finance::Quote->new('alphavantage' => {API_KEY => '...'})
    my $q = Finance::Quote->new('IEXCloud', 'iexcloud' => {API_KEY => '...'});

A Finance::Quote object uses one or more methods to fetch quotes for
securities. `new` constructs a Finance::Quote object and enables the caller
to load only specific methods, set parameters that control the behavior of the
fetch method, and pass method-specific parameters to the corresponding method.

- `timeout =` T> sets the web request timeout to `T` seconds
- `failover =` B> where `B` is a boolean value indicating if failover is acceptable
- `fetch_currency =` C> sets the desired currency code to `C` for fetch results
- `required_labels =` A> sets the required labels for fetch results to array `A`
- `<Module-name`> as a string is the name of a specific Finance::Quote::Module to load
- `<method-name` => H> passes hash `H` to the method-name constructor

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

## GET\_DEFAULT\_CURRENCY\_FIELDS

    my @fields = Finance::Quote::get_default_currency_fields();

`get_default_currency_fields` returns the standard list of fields in a quote
that are automatically converted during currency conversion. Individual modules
may override this list.

## GET\_DEFAULT\_TIMEOUT

    my $value = Finance::Quote::get_default_timeout();

`get_default_timeout` returns the current Finance::Quote default timeout in
seconds for web requests. Finance::Quote does not specify a default timeout,
deferring to the underlying user agent for web requests. So this function
will return undef unless `set_default_timeout` was previously called.

## SET\_DEFAULT\_TIMEOUT

    Finance::Quote::set_default_timeout(45);

`set_default_timeout` sets the Finance::Quote default timeout to a new value.

## GET\_METHODS

    my @methods = Finance::Quote::get_methods();

`get_methods` returns the list of methods that can be passed to `new` when
creating a quoter object and as the first argument to `fetch`.

# PUBLIC OBJECT METHODS

## B\_TO\_BILLIONS

    my $value = $q->B_to_billions("20B");

`B_to_billions` is a utility function that expands a numeric string with a "B"
suffix to the corresponding multiple of 1000000000.

## DECIMAL\_SHIFTUP

    my $value = $q->decimal_shiftup("123.45", 1);  # returns 1234.5
    my $value = $q->decimal_shiftup("0.25", 1);    # returns 2.5

`decimal_shiftup` moves a the decimal point in a numeric string the specified
number of places to the right.

## FETCH

    my %stocks  = $q->fetch("alphavantage", "IBM", "MSFT", "LNUX");
    my $hashref = $q->fetch("usa", "IBM", "MSFT", "LNUX");

`fetch` takes a method as its first argument and the remaining arguments are
treated as securities.  If the quoter `$q` was constructed with a specific
method or methods, then only those methods are available.

When called in an array context, a hash is returned.  In a scalar context, a
reference to a hash will be returned. 

The keys for the returned hash are `{SECURITY,LABEL}`.  For the above example
call, `$stocks{"IBM","high"}` is the high value for IBM as determined by the
AlphaVantage method.

## GET\_FAILOVER

    my $failover = $q->get_failover();

Failover is when the `fetch` method attempts to retrieve quote information for
a security from alternate sources when the requested method fails.
`get_failover` returns a boolean value indicating if the quoter object will
use failover or not.

## SET\_FAILOVER

    $q->set_failover(False);

`set_failover` sets the failover flag on the quoter object. 

## GET\_FETCH\_CURRENCY

    my $currency = $q->get_fetch_currency();

`get_fetch_currency` returns either the desired currency code for the quoter
object or undef if no target currency was set during construction or with the
`set_fetch_currency` function.

## SET\_FETCH\_CURRENCY

    $q->set_fetch_currency("FRF");  # Get results in French Francs.

`set_fetch_currency` method is used to request that all information be
returned in the specified currency.  Note that this increases the chance
stock-lookup failure, as remote requests must be made to fetch both the stock
information and the currency rates.  In order to improve reliability and speed
performance, currency conversion rates are cached and are assumed not to change
for the duration of the Finance::Quote object.

Currency conversions are requested through AlphaVantage, which requires an API
key.  Please see Finance::Quote::AlphaVantage for more information.

## GET\_REQUIRED\_LABELS

    my @labels = $q->get_required_labels();

`get_required_labels` returns the list of labels that must be populated for a
security quote to be considered valid and returned by `fetch`.

## SET\_REQUIRED\_LABELS

    my $labels = ['close', 'isodate', 'last'];
    $q->set_required_labels($labels);

`set_required_labels` updates the list of required labels for the quoter object.

## GET\_TIMEOUT

    my $timeout = $q->get_timeout();

`get_timeout` returns the timeout in seconds the quoter object is using for
web requests.

## SET\_TIMEOUT

    $q->set_timeout(45);

`set_timeout` updated teh timeout in seconds for the quoter object.

## GET\_USER\_AGENT

    my $ua = $q->get_user_agent();

`get_user_agent` returns the LWP::UserAgent the quoter object is using for web
requests.

## ISOTIME

    $q->isoTime("11:39PM");    # returns "23:39"
    $q->isoTime("9:10 AM");    # returns "09:10"

`isoTime` returns an ISO formatted time.

# PUBLIC CLASS OR OBJECT METHODS

The following methods are available as class methods, but can also be called
from Finance::Quote objects.

## SCALE\_FIELD

    my $value = Finance::Quote->scale_field('1023', '0.01')

`scale_field` is a utility function that scales the first argument by the
second argument.  In the above example, `value` is `'10.23'`.

## CURRENCY

    my $value = Finance::Quote->currency('15.95 USD', 'AUD');

`currency` converts a value with a currency code suffix to another currency
using the current exchange rate returned by the AlphaVantage method.
AlphaVantage requires an API key. See Finance::Quote::AlphaVantage for more
information.

## CURRENCY\_LOOKUP

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

## PARSE\_CSV

    my @list = Finance::Quote::parse_csv($string);

`parse_csv` is a utility function for spliting a comma seperated value string
into a list of terms, treating double-quoted strings that contain commas as a
single value.

## PARSE\_CSV\_SEMICOLON

    my @list = Finance::Quote::parse_csv_semicolon($string);

`parse_csv` is a utility function for spliting a semicolon seperated value string
into a list of terms, treating double-quoted strings that contain semicolons as a
single value.

# ENVIRONMENT

Finance::Quote respects all environment that your installed version of
LWP::UserAgent respects.  Most importantly, it respects the http\_proxy
environment variable.

# BUGS

There are no ways for a user to define a failover list.

The two-dimensional hash is a somewhat unwieldly method of passing around
information when compared to references

There is no way to override the default behaviour to cache currency conversion
rates.

# COPYRIGHT & LICENSE

    Copyright 1998, Dj Padzensky
    Copyright 1998, 1999 Linas Vepstas
    Copyright 2000, Yannick LE NY (update for Yahoo Europe and YahooQuote)
    Copyright 2000-2001, Paul Fenwick (updates for ASX, maintenance and release)
    Copyright 2000-2001, Brent Neal (update for TIAA-CREF)
    Copyright 2000 Volker Stuerzl (DWS and VWD support)
    Copyright 2000 Keith Refson (Trustnet support)
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

Finance::Quote::AEX,
Finance::Quote::AIAHK,
Finance::Quote::ASEGR,
Finance::Quote::ASX,
Finance::Quote::BMONesbittBurns,
Finance::Quote::BSEIndia,
Finance::Quote::BSERO,
Finance::Quote::Bourso,
Finance::Quote::CSE,
Finance::Quote::Cdnfundlibrary,
Finance::Quote::Citywire,
Finance::Quote::Cominvest,
Finance::Quote::Currencies,
Finance::Quote::DWS,
Finance::Quote::Deka,
Finance::Quote::FTPortfolios,
Finance::Quote::FTfunds,
Finance::Quote::Fidelity,
Finance::Quote::FidelityFixed,
Finance::Quote::Finanzpartner,
Finance::Quote::Fool,
Finance::Quote::Fundata
Finance::Quote::GoldMoney,
Finance::Quote::HEX,
Finance::Quote::HU,
Finance::Quote::IEXCloud,
Finance::Quote::IndiaMutual,
Finance::Quote::LeRevenu,
Finance::Quote::MStaruk,
Finance::Quote::ManInvestments,
Finance::Quote::Morningstar,
Finance::Quote::MorningstarAU,
Finance::Quote::MorningstarCH,
Finance::Quote::MorningstarJP,
Finance::Quote::NSEIndia,
Finance::Quote::NZX,
Finance::Quote::Oslobors,
Finance::Quote::Platinum,
Finance::Quote::SEB,
Finance::Quote::TNetuk,
Finance::Quote::TSP,
Finance::Quote::TSX,
Finance::Quote::Tdefunds,
Finance::Quote::Tdwaterhouse,
Finance::Quote::Tiaacref,
Finance::Quote::Troweprice,
Finance::Quote::Trustnet,
Finance::Quote::USFedBonds,
Finance::Quote::Union,
Finance::Quote::VWD,
Finance::Quote::XETRA,
Finance::Quote::YahooJSON,
Finance::Quote::YahooYQL,
Finance::Quote::ZA,
Finance::Quote::ZA\_UnitTrusts

You should have received the Finance::Quote hacker's guide with this package.
Please read it if you are interested in adding extra methods to this package.
The latest hacker's guide can also be found on GitHub at
https://github.com/finance-quote/finance-quote/blob/master/Documentation/Hackers-Guide
