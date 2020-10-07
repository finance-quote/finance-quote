# NAME

Finance::Quote - Get stock and mutual fund quotes from various exchanges

# SYNOPSIS

    use Finance::Quote;
    $q = Finance::Quote->new;

    $q->timeout(60);

    $conversion_rate = $q->currency("AUD","USD");
    $q->set_currency("EUR");  # Return all info in Euros.

    $q->require_labels(qw/price date high low volume/);

    $q->failover(1); # Set failover support (on by default).

    %quotes  = $q->fetch("nasdaq",@stocks);
    $hashref = $q->fetch("nyse",@stocks);

# DESCRIPTION

This module gets stock quotes from various internet sources, including
Yahoo! Finance, Fidelity Investments, and the Australian Stock Exchange.
There are two methods of using this module -- a functional interface
that is deprecated, and an object-orientated method that provides
greater flexibility and stability.

With the exception of straight currency exchange rates, all information
is returned as a two-dimensional hash (or a reference to such a hash,
if called in a scalar context).  For example:

    %info = $q->fetch("australia","CML");
    print "The price of CML is ".$info{"CML","price"};

The first part of the hash (eg, "CML") is referred to as the stock.
The second part (in this case, "price") is referred to as the label.

## LABELS

When information about a stock is returned, the following standard labels
may be used.  Some custom-written modules may use labels not mentioned
here.  If you wish to be certain that you obtain a certain set of labels
for a given stock, you can specify that using require\_labels().

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

If all stock lookups fail (possibly because of a failed connection) then
the empty list may be returned, or undef in a scalar context.

# INSTALLATION

Please note that the Github repository is not meant for general users
of Finance::Quote for installation.

If you downloaded the Finance-Quote-N.NN.tar.gz tarball from CPAN
(N.NN is the version number, ex: Finance-Quote-1.47.tar.gz),
run the following commands:
    
    tar xzf Finance-Quote-1.47.tar.gz
    cd Finance-Quote-1.47.tar.gz
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

# AVAILABLE METHODS

## NEW

    my $q = Finance::Quote->new;
    my $q = Finance::Quote->new("ASX");
    my $q = Finance::Quote->new("-defaults", "CustomModule");

With no arguents, this creates a new Finance::Quote object
with the default methods.  If the environment variable
FQ\_LOAD\_QUOTELET is set, then the contents of FQ\_LOAD\_QUOTELET
(split on whitespace) will be used as the argument list.  This allows
users to load their own custom modules without having to change
existing code.  If you do not want users to be able to load their own
modules at run-time, pass an explicit argumetn to ->new() (usually
"-defaults").

When new() is passed one or more arguments, an object is created with
only the specified modules loaded.  If the first argument is
"-defaults", then the default modules will be loaded first, followed
by any other specified modules.

Note that the FQ\_LOAD\_QUOTELET environment variable must begin
with "-defaults" if you wish the default modules to be loaded.

Any modules specified will automatically be looked for in the
Finance::Quote:: module-space.  Hence,
Finance::Quote->new("ASX") will load the module Finance::Quote::ASX.

Please read the Finance::Quote hacker's guide for information
on how to create new modules for Finance::Quote.

## FETCH

    my %stocks  = $q->fetch("usa","IBM","MSFT","LNUX");
    my $hashref = $q->fetch("usa","IBM","MSFT","LNUX");

Fetch takes an exchange as its first argument.  The second and remaining
arguments are treated as stock-names.  In the standard Finance::Quote
distribution, the following exchanges are recognised:

    australia   Australan Stock Exchange
    dwsfunds    Deutsche Bank Gruppe funds
    fidelity    Fidelity Investments
    tiaacref    TIAA-CREF
    troweprice    T. Rowe Price
    europe    European Markets
    canada    Canadian Markets
    usa     USA Markets
    nyse    New York Stock Exchange
    nasdaq    NASDAQ
    uk_unit_trusts  UK Unit Trusts
    vwd     Vereinigte Wirtschaftsdienste GmbH

When called in an array context, a hash is returned.  In a scalar
context, a reference to a hash will be returned.  The structure
of this hash is described earlier in this document.

The fetch method automatically arranges for failover support and
currency conversion if requested.

If you wish to fetch information from only one particular source,
then consult the documentation of that sub-module for further
information.

## SOURCES

    my @sources = $q->sources;
    my $listref = $q->sources;

The sources method returns a list of sources that have currently been loaded and
can be passed to the fetch method.  If you're providing a user with a list of
sources to choose from, then it is recommended that you use this method.

## CURRENCY\_LOOKUP

    $currencies_by_name = $q->currency_lookup( name => 'Australian' );
    $currencies_by_code = $q->currency_lookup( code => qr/^b/i      );
    $currencies_by_both = $q->currency_lookup( name => qr/pound/i
                                             , code => 'GB'         );

The currency\_lookup method provides a search against the known currencies. The
list of currencies is based on the available currencies in the Yahoo Currency
Converter (the list is stored within the module as the list should be fairly
static).

The lookup can be done by currency name (ie "Australian Dollar"), by
code (ie "AUD") or both. You can pass either a scalar or regular expression
as a search value - scalar values are matched by substring while regular
expressions are matched as-is (no changes are made to the expression).

See [Finance::Quote::Currencies::fetch\_live\_currencies](https://metacpan.org/pod/Finance%3A%3AQuote%3A%3ACurrencies%3A%3Afetch_live_currencies) (and the
`t/currencies.t` test file) for a way to make sure that the stored
currency list is up to date.

## CURRENCY

    $conversion_rate = $q->currency("USD","AUD");

The currency method takes two arguments, and returns a conversion rate
that can be used to convert from the first currency into the second.
In the example above, we've requested the factor that would convert
US dollars into Australian dollars.

The currency method will return a false value if a given currency
conversion cannot be fetched.

At the moment, currency rates are fetched from Yahoo!, and the
information returned is governed by Yahoo!'s terms and conditions.
See Finance::Quote::Yahoo for more information.

## SET\_CURRENCY

    $q->set_currency("FRF");  # Get results in French Francs.

The set\_currency method can be used to request that all information be
returned in the specified currency.  Note that this increases the
chance stock-lookup failure, as remote requests must be made to fetch
both the stock information and the currency rates.  In order to
improve reliability and speed performance, currency conversion rates
are cached and are assumed not to change for the duration of the
Finance::Quote object.

At this time, currency conversions are only looked up using Yahoo!'s
services, and hence information obtained with automatic currency
conversion is bound by Yahoo!'s terms and conditions.

## FAILOVER

    $q->failover(1);  # Set automatic failover support.
    $q->failover(0);  # Disable failover support.

The failover method takes a single argument which either sets (if
true) or unsets (if false) automatic failover support.  If automatic
failover support is enabled (default) then multiple information
sources will be tried if one or more sources fail to return the
requested information.  Failover support will significantly increase
the time spent looking for a non-existant stock.

If the failover method is called with no arguments, or with an
undefined argument, it will return the current failover state
(true/false).

## USER\_AGENT

    my $ua = $q->user_agent;

The user\_agent method returns the LWP::UserAgent object that
Finance::Quote and its helpers use.  Normally this would not
be useful to an application, however it is possible to modify
the user-agent directly using this method:

    $q->user_agent->timeout(10);  # Set the timeout directly.

## SCALE\_FIELD

    my $pounds = $q->scale_field($item_in_pence,0.01);

The scale\_field() function is a helper that can scale complex fields such
as ranges (eg, "102.5 - 103.8") and other fields where the numbers should
be scaled but any surrounding text preserved.  It's most useful in writing
new Finance::Quote modules where you may retrieve information in a
non-ISO4217 unit (such as cents) and would like to scale it to a more
useful unit (like dollars).

## ISOTIME

    $q->isoTime("11:39PM");    # returns "23:39"
    $q->isoTime("9:10 AM");    # returns "09:10"

This function will return a isoformatted time

# ENVIRONMENT

Finance::Quote respects all environment that your installed
version of LWP::UserAgent respects.  Most importantly, it
respects the http\_proxy environment variable.

# BUGS

There are no ways for a user to define a failover list.

The two-dimensional hash is a somewhat unwieldly method of passing
around information when compared to references.  A future release
is planned that will allow for information to be returned in a
more flexible $hash{$stock}{$label} style format.

There is no way to override the default behaviour to cache currency
conversion rates.

# COPYRIGHT & LICENSE

    Copyright 1998, Dj Padzensky
    Copyright 1998, 1999 Linas Vepstas
    Copyright 2000, Yannick LE NY (update for Yahoo Europe and YahooQuote)
    Copyright 2000-2001, Paul Fenwick (updates for ASX, maintainence and release)
    Copyright 2000-2001, Brent Neal (update for TIAA-CREF)
    Copyright 2000 Volker Stuerzl (DWS and VWD support)
    Copyright 2000 Keith Refson (Trustnet support)
    Copyright 2001 Rob Sessink (AEX support)
    Copyright 2001 Leigh Wedding (ASX updates)
    Copyright 2001 Tobias Vancura (Fool support)
    Copyright 2001 James Treacy (TD Waterhouse support)
    Copyright 2008 Erik Colson (isoTime)

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or (at
your option) any later version.

Currency information fetched through this module is bound by
Yahoo!'s terms and conditons.

Other copyrights and conditions may apply to data fetched through this
module.  Please refer to the sub-modules for further information.

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

Finance::Quote::AEX, Finance::Quote::AIAHK, Finance::Quote::ASEGR,
Finance::Quote::ASX, Finance::Quote::BMONesbittBurns, Finance::Quote::BSERO,
Finance::Quote::Bourso, Finance::Quote::CSE, Finance::Quote::Cdnfundlibrary,
Finance::Quote::Citywire, Finance::Quote::Cominvest,
Finance::Quote::Currencies, Finance::Quote::DWS, Finance::Quote::Deka,
Finance::Quote::FTPortfolios, Finance::Quote::FTfunds,
Finance::Quote::Fidelity, Finance::Quote::FidelityFixed,
Finance::Quote::FinanceCanada, Finance::Quote::Finanzpartner,
Finance::Quote::Fool, Finance::Quote::GoldMoney, Finance::Quote::HEX,
Finance::Quote::HU, Finance::Quote::IEXCloud, Finance::Quote::IndiaMutual,
Finance::Quote::LeRevenu, Finance::Quote::MStaruk,
Finance::Quote::ManInvestments, Finance::Quote::Morningstar,
Finance::Quote::MorningstarAU, Finance::Quote::MorningstarCH,
Finance::Quote::MorningstarJP, Finance::Quote::NZX, Finance::Quote::Oslobors,
Finance::Quote::Platinum, Finance::Quote::SEB, Finance::Quote::TNetuk,
Finance::Quote::TSP, Finance::Quote::TSX, Finance::Quote::Tdefunds,
Finance::Quote::Tdwaterhouse, Finance::Quote::Tiaacref,
Finance::Quote::Troweprice, Finance::Quote::Trustnet,
Finance::Quote::USFedBonds, Finance::Quote::Union, Finance::Quote::VWD,
Finance::Quote::YahooJSON, Finance::Quote::YahooYQL, Finance::Quote::ZA,
Finance::Quote::ZA_UnitTrusts

You should have received the Finance::Quote hacker's guide with this package.
Please read it if you are interested in adding extra methods to this package.
The latest hacker's guide can also be found on GitHub at
https://github.com/finance-quote/finance-quote/blob/master/Documentation/Hackers-Guide
