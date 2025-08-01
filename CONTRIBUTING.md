# Introduction

This is a guide for those who wish to contribute to Finance::Quote,
or create their own Finance::Quote pluggable module. As an open project,
Finance::Quote appreciates contributions from the community.

The initial version of this document is derived from the
[Hackers Guide](https://github.com/finance-quote/finance-quote/blob/master/Documentation/Hackers-Guide)

This guide assumes that you are familiar with Perl.

## Finance::Quote People

- Core Team

    These people are the only people allowed to merge pull requests.
    A subset of these people have the permissions to push releases to
    the CPAN Finance::Quote namespace.

- Contributors

    This team will help review issues and pull requests.

- You!

    Many features and bug fixes have come from the open source community
    as a whole. Finance::Quote depends on you as just as much as it does
    the team members.

# Ways to Help

- Coding

    The primary way to contribute is obviously coding. That could mean
    addressing reported issues, improving existing modules, or
    creating a new module to retrieve data.

- Documentation

    But you don't need to be a Perl programmer to contribute! We welcome
    updates to the documentation on the Github repository, or the
    pages at Sourceforge ([https://sourceforge.net/projects/finance-quote/](https://sourceforge.net/projects/finance-quote/)
    and [https://finance-quote.sourceforge.net/](https://finance-quote.sourceforge.net/)).

- Discussions

    There is also more of an informal way to help by joining any
    of the Finance::Quote
    [Discussions](https://github.com/finance-quote/finance-quote/discussions)
    as well as the mailing lists hosted at Sourceforge
    ([https://sourceforge.net/p/finance-quote/mailman/](https://sourceforge.net/p/finance-quote/mailman/)).

# Setup a Development Environment

To develop and test modules, you need a clone of the Finance-Quote
git repository, a recent version of perl, and the Dist::Zilla module
and its dependencies. The following steps provide a recipe for setup.

- A: Clone the git repo

        $ git clone https://github.com/finance-quote/finance-quote.git
         

- B: (Optional) Install latest stable copy of perl in ~/perl5

        $ curl -L https://install.perlbrew.pl | bash
        $ echo "source ~/perl5/perlbrew/etc/bashrc" >> ~/.bash_profile     # or the equivalent for your shell
        $ perlbrew --notest install perl-5.28.1                            # --notest is risky, but significant speeds installation
        $ perlbrew switch perl-5.28.1
        $ perlbrew install-cpanm
        $ cpanm install Dist::Zilla
           
        # inside the finance-quote directory 
        # remove --missing to install missing & upgrade existing required package
        
        $ dzil authordeps --missing | cpanm --notest
        $ dzil listdeps --missing | cpanm --notest

        $ cpanm install Data::Dumper::Perltidy Smart::Comments
         

- C: Test out finance-quote

          # Light-weight test mode that skips all online tests

          $ dzil test
        
          # To run all the skipped tests, you need three environment variables:
          #  TEST_AUTHOR          - when set, tests are run to check for required modules
          #  ONLINE_TEST          - when set, online tests are executed
          #  ALPHAVANTAGE_API_KEY - free API key available from https://www.alphavantage.co
          #
          # Using bash syntax to set environment variables

          $ cpanm Test::Pod Test::Pod::Coverage Test::Kwalitee Test::Perl::Critic
          $ TEST_AUTHOR=1 ONLINE_TEST=1 ALPHAVANTAGE_API_KEY=<YOUR API KEY> dzil test

          # To do an online test for one module 

          $ ONLINE_TEST=1 dzil run prove -lv t/iexcloud.t

          # Use prove to during test development - it is fast

          $ prove -lv t/fq-class-methods.t

# How to write a Finance::Quote module

Finding a source of information, and writing code to parse and interpret
that information is a difficult task. As such, we've aimed to make
writing a Finance::Quote module as easy as possible. There are only
a few simple rules you need to follow:

## The package name

Finance::Quote expects that its loadable modules will be in the
Finance::Quote namespace somewhere. Hence, if you were writing
a module called "DodgyBank" that returned information on DodgyBank's
managed funds, a reasonable name for that module would be
Finance::Quote::DodgyBank.

## The methodinfo() subroutine

Your module must have a subroutine named methodinfo(). Future versions
of GnuCash may use this to dynamically determine the data sources
available. The subroutine returns a nested data structure of the
method(s) defined in the module, along with additional information.

In this example, the main method is "foobar". But this method can be used
for failover methods "usa", "nyse", or "nasdaq".

    sub methodinfo {
        return ( 
            foobar   => $METHODHASH,
            usa      => $METHODHASH,
            nyse     => $METHODHASH,
            nasdaq   => $METHODHASH,
        );
    }

The information for the method in contained in another data structure.
In our example, "$METHODHASH". This data structure will contain a brief name,
any features such as needing a API key, and the labels (data fields) the
method will returns.

    our $DISPLAY    = 'FooBar';
    our $FEATURES   = {'API_KEY' => 'registered user API key'};
    our @LABELS     = qw/date isodate open high low close volume last net p_change/;
    our $METHODHASH = {subroutine => \&foobar, 
                       display => $DISPLAY, 
                       labels => \@LABELS,
                       features => $FEATURES};

It is uncommon, but some modules may contain 2 or more different methods.
Not to be confused with failover methods.
In this example, a module to retrieve data from "Dodgy Bank, USA" may
have a method defined for funds and another for bonds. Both require an
API key.

    our $FUNDSDISPLAY    = 'Dodgy Bank Funds';
    our $FEATURES   = {'API_KEY' => 'registered user API key'};
    our @LABELS     = qw/date isodate open high low close volume last net p_change/;
    our $FUNDSHASH = {subroutine => \&funds, 
                       display => $FUNDSDISPLAY, 
                       labels => \@LABELS,
                       features => $FEATURES};

    our $BONDSDISPLAY    = 'Dodgy Bank Bonds';
    our $BONDSHASH = {subroutine => \&bonds, 
                       display => $BONDSDISPLAY, 
                       labels => \@LABELS,
                       features => $FEATURES};

    sub methodinfo {
        return ( 
            dodgyfunds   => $FUNDSHASH,
            dodgybonds   => $BONDSHASH,
        );
    }

## The methods() subroutine

Your module must have a subroutine named methods(). This function will
be called by the Finance::Quote harness when it loads your module, and
is used to determine which methods your module provides. The methods()
function must return a hash of method names and subroutine references.
For example, if you had written a module which provides access to
DodgyBank's managed funds, you might have the following

        package Finance::Quote::DodgyBank;
        .
        .
        sub methods {
        my %m = methodinfo(); return map {$_ => $m{$_}{subroutine} } keys %m;
        }

This would indicate that your package provides methods for
"dodgyfunds" and "dodgyloans", and that the subroutines
"funds" and "loans" should be called to access that information.

The following method names should be used for the following information
sources:

        Method-Name                     Source
        ---------------------------------------------------------
        australia                       Australian Stocks
        canada                          Canadian Stocks
        europe                          European Stocks
        fidelity                        Fidelity Investments
        nasdaq                          NASDAQ
        nyse                            New York Stock Exchange
        tiaacref                        TIAA-CREF
        troweprice                      T. Rowe. Price
        usa                             USA Stocks

Method names should be lower-case, consist of alphanumeric characters
(including underscore) only, and always begin with a letter. This is
not enforced, but future versions of the Finance::Quote framework may 
rely upon it.

It's strongly recommended that you also provide a unique name for your
method, in case you (or others) wish to call that method exclusively
in code. Hence if you had written a module to fetch information from
the NYSE from Yohoo! and named the subroutine "yohoo", your methodinfo subroutine may look like:

    sub methodinfo {
        return (
          yohoo => $METHODHASH,
          nyse  => $METHODHASH,
        );
    }

This means that people who only want to use your function can use
$quoter->fetch('yohoo',@stocks), but those who don't care where
their NYSE stock information is fetched from can use
$quoter->fetch('nyse',@stocks). The first form allows you to know exactly
where the information is coming from. In the second, failover methods mean
that many different functions could be used to fetch the stock information,
not just the one you have defined.

## The functions specified by methods()

The functions referred to by methods() will be passed a Finance::Quote
object when called, and a list of zero or more symbol names. The
Finance::Quote object provides the following ready-to-use methods:

        user_agent();   # Provides a ready-to-use LWP::UserAgent

        parse_csv();    # Parses a list of comma-separated values
                        # and returns an array.

The user\_agent() method should be used if possible to fetch the information,
as it should be already configured to use the timeout, proxy, and other
settings requested by the calling program.

Your function should return a two-dimensional hash as specified in the
Finance::Quote man-page. Eg:

        $hash{$symbol,'last'} = $last_price;
        $hash{$symbol,'name'} = $stock_name;
        # etc etc.

When returning your hash, you should check the context that your
function was called in. If it was called in a scalar context, then
you should return a hashref instead. This can be easily done
with the following:

        return wantarray() ? %hash : \%hash;

It is ESSENTIAL that your hash contain a true value for {$symbol,'success'}
for information that has been successfully obtained. If the information
was not obtained for any reason, then {$symbol,'success'} should
be set to a false value (preferably 0), and a human-readable error
message placed in {$symbol,'errormsg'}. The following code snippet
demonstrates this:

        sub funds {

                my $quoter = shift;     # The Finance::Quote object.
                my @stocks = @_;
                my %info;

                my $DODGY_URL = "http://dodgybank.xxx/funds.csv?";

                my $ua = $quoter->user_agent;   # This gives us a user-agent
                                                # with timeouts, proxies,
                                                # etc already configured.

                my $response = $ua->request(GET $DODGY_URL);
                unless ($response->is_success) {
                        foreach my $stock (@stocks) {
                                $info{$stock,"success"} = 0;
                                $info{$stock,"errormsg"} = "HTTP failure";
                        }
                        return wantarray ? %info : \%info;
                }

                # Do stuff with the information returned....

        }

It is valid to use "return" with no arguments if all stock lookups failed,
however this does not provide any information as to WHY the lookups
failed. If at all possible, the errormsg labels should be set.

It is also very very strongly recommended that you place your module's
name in the {$stock,"source"} field. This allows others to check where
information was obtained, and to use it appropriately.

## The parameters() subroutine - Modules requiring API Keys

Some data sources require an API Key (sometimes called a token) in
order to access the securities or exchange data. AlphaVantage.pm
is one example.

In order to assist programs using Finance::Quote to identify those
modules that require an API Key please include this function if
your module is using a data source that requires a key/token.

        sub parameters {
                return ('API_KEY');
        }

## Currency

Finance::Quote has support for multiple currencies and for currency
conversion. As long as you provide a little bit of information about
the information you are returning, the Finance::Quote framework can
do all the hard stuff for you.

If you are returning information on a stock in a particular currency,
then you can enter the ISO currency code into the "currency" field
associated with the stock. Eg:

        $info{$stock,"currency"} = "AUD";  # Australian Dollars

If the information you are returning does not have a currency
(because it's an index like the Dow Jones Industrial or the
All Oridinaries, or because you're returning percentages) then
you should not set the currency field for that stock. Finance::Quote
knows not to attempt currency conversion for stocks without
a currency field.

If you do have a currency field, then by default Finance::Quote will
arrange for the automatic conversion of a number of fields. By
default, these fields are last, high, low, net, bid, ask, close, open, 
day\_range, year\_range, eps, div, cap, nav and price. Of course,
there may be some cases where this set is not appropriate, or where there
are extra fields that should be converted. This can be indicated
by writing a function called "currency\_fields()" in your module,
that returns a list of fields that can undergo currency conversion.
Eg:

        sub currency_fields {
                return qw/high low price bid/;
        }

currency\_fields() will be passed a Finance::Quote object as its
first argument, and a method called default\_currency\_fields()
is available through this object. This is useful if you want
to use the defaults, but also add some of your own:

        sub currency_fields {
                my $quoter = shift;
                return ($quoter->default_currency_fields, "commission");
        }

In the example above, the default fields would be available for currency
conversion, but the "commission" field would also be converted.

## Development & Debugging Code

There are multiple ways to include extra code in Perl modules to facilitate
development and debugging. For Finance::Quote modules, please use the following
strategy that uses a combination of a DEBUG constant and the Smart::Comments
module. If DEBUG is in the environment and set to a value that Perl evaluates
to true, then Smart::Comments is active and code blocks wrapped with if(DEBUG)
are also active. Otherwise, all the debugging code disappears during
compilation.

     use strict;                          # use strict & warnings FIRST
     use warnings;

     use constant DEBUG => $ENV{DEBUG};   # create a constant from the environment
     
     use if DEBUG, 'Smart::Comments';     # conditionally use Smart::Comments
     use if DEBUG, 'Another::Module';     # example module only needed for debugging
    
     use LWP::UserAgent;                  # and finally production module dependencies
     
     my %h = ('a' => 1);                  # just an example variable
     
     # These first two lines are always a comment. The third line
     # prints a debugging string if DEBUG is in the environment.
     ### [<now>] h: \%h
     
     # For more complicated debugging, the following if-block
     # will disappear during compilation because of constant folding.
     if (DEBUG) {
       print "More complex debugging code\n";
     }

## Dates

Do not parse dates directly in your module. Instead you should use
the function $q->store\_date(), which handles a variety of date
formats. In its simplest form, you simply tell the function what
format the date is in and it handles all the parsing. The code should
look similar to this:

    $quoter->store_date(\%info, $stock, {eurodate => @$row[1]});

If the web site doesn't have a data available, somply call the
function this way:

    $quoter->store_date(\%info, $stock, {today => 1});

See the documentation in Quote.pm for more information.

## Things to avoid

Some sources of information will provide more stock information than
requested. Some code may rely upon your code only returning information
about the stocks that the caller requested. As such, you should
never return information about stocks that were not requested, even
if you fetch and/or process that information.

## Using your new module

Using your new module is easy. Normally when using Finance::Quote you'd
do something like the following:

        use Finance::Quote;
        my $quoter = Finance::Quote->new();

To use your new module, simply specify the module name (without
the Finance::Quote prefix) in the new function. Hence:

        use Finance::Quote;
        my $quoter = Finance::Quote->new("DodgyBank");

The DodgyBank methods will now be available:

        my %loaninfo = $quoter->fetch("dodgyloans","car","boat","house");
        my %fundinfo = $quoter->fetch("dodgyfunds","lotto","shares");

The resulting Finance::Quote object will also arrange for your functions
to be callable without using fetch. This syntax is strongly discouraged,
as it results in pollution of the Finance::Quote namespace and provides
little advantages over the fetch() method:

        my %loaninfo = $quoter->dodgyloans("car","boat","loan");

This mainly exists to maintain compatibility with previous versions of
Finance::Quote.

# How to write a Finance::Quote::CurrencyRates module

Currency Rate modules carryout a single task: Given two currencies, return
multipliers that describe the relative value of the currencies. In the
simplest case, one multiplier is "1.0" and the other multiplier is the exchange
rate between the two currencies. In the other case, the multipliers reflect the
relative value of each currency to a third base currency.

For example, on 2020-10-30, the European Central Bank reported that 1.1698 USD
(United States Dollar) was equivalent to 1.00 EUR (Euro). It also reported that
0.90208 GBP (Pound Sterling) was equivalent to 1.00 EUR. To convert from USD to
GBP, the following from/to multipliers are equivalent:

    from       to         Base Currency
    --------   --------   -------------
    1.16980    0.90208    EUR
    1.00000    0.77114    USD
    1.29678    1.00000    GBP

Depending on the source of the currency rates, it may be more convenient for a
currency rate module to return multipliers that are relative to a third
currency (first row), the conversion rate (the second row), or the inverse
conversion rate (the third row).

Currency rate modules should avoid carrying out arithmetic and leave it to
Finance::Quote to use the multipliers to compute the final conversion value.

## The package name

Currency rate modules belong in the Finance::Quote::CurrencyRates namespace and
the name of the module should be descriptive. Use PascalCase (upper CamelCase)
for the module name.

## The new() constructor

Currency rate modules are called from a Finance::Quote quoter object when
currency conversion is either explicitly requested from a caller or to convert
a fetched security price to a user specified currency. When instantiating a
quoter object, the caller may pass module specific parameters. Suppose the
currency rate module ExampleRates requires an API key and also optionally
supports caching rates during the lifetime of the quoter object. Then the
code

    my $q = Finance::Quote->new('currency_rates' => 
                                {order        => ['ExampleRates', 'ECB'],
                                 examplerates => {API_KEY => 'x01234566', 
                                                  cache   => True}});

instantiates a quoter that uses ExampleRates first and falls back the ECB
for currency rates. When ExampleRates is used, the API\_KEY can cache options
are configured through a module specific hash.

Finance::Quote passes just the hash containing the API\_KEY and cache key/value
pairs to ExampleRates->new() as a hash reference. If the caller does not
specify an ExampleRates key in the currency\_rates hash, then ExampleRates->new()
is called with no arguments. ExamplesRates may, but is not required, to 
alternately read the API key from an environment variable.

Clearly document all currency rate module options in the POD documentation for
the module.

## The multipliers() function

Finance::Quote calls the currency rate object method multipliers() with the
arguments (object, user\_agent, from, to), where

    object was previously instantiated with a call to new()
    user_agent is a LWP::UserAgent
    from is an ISO currency code
    to is an ISO currency code

multipliers() must a pair of multipliers (from\_multiplier, to\_multiplier),
where

    from_multiplier is a floating point value 
    to_multiplier is a floating point value

and to\_multiplier/from\_multiplier will convert a value in currency "from"
into currency "to".

On error, multipliers() must either return undef or throw and exception
with die().

# How to contribute your module to the world

Check list:

- Created a well-named module file in the Finance directory tree.
- Included POD documentation at the bottom of module file.
- Included a VERSION comment just \*after\* the use module statements.
- Added the module name in alphabetical order to the @MODULES or @CURRENCY\_MODULES variable in Quote.pm.
- Added the module name in alphabetical order in the SEE ALSO section of the Quote.pm POD.
- Created a well-named test file in the t/ directory, including a test that succeeds and a test that fails.
- Ensure tests 00-store-date.t, 01-pod.t, 02-pod-coverage.t, 03-kwalitee.t, 04-critic.t, 05-data-dumper.t pass.
- Added module information in alphabetical order to the Modules-README.yml file.
- Add a quick description of the change/addition to the Changes file. Most recent changes at the top of the list. Add new lines just below the {{$NEXT}} label at the top of the file.

Contributions to Finance-Quote are best presented as pull requests on GitHub.com. 

1. Create a GitHub account and sign-in
2. Go to https://github.com/finance-quote/finance-quote
3. Click "Fork" in the upper-right corner
4. Commit your new module and other code changes to the fork
5. Click "New Pull Request" on https://github.com/finance-quote/finance-quote
6. Click "Compare Across Forks"
7. Select the appropriate commits and create the merge request

Contact developers at [mailto:finance-quote-devel@sourceforge.net](mailto:finance-quote-devel@sourceforge.net) to discuss
new modules, ask questions, or get help opening a merge request.

# How to find out more

The Finance::Quote GitHub page is located at

[https://github.com/finance-quote/finance-quote](https://github.com/finance-quote/finance-quote)

and contains information about the project and links to older SourceForge
documentation.

# How to join the mailing lists

There are two mailing lists for Finance::Quote. These can both be accessed
from:

[https://sourceforge.net/p/finance-quote/mailman/](https://sourceforge.net/p/finance-quote/mailman/)
