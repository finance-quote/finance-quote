#!/usr/bin/perl -w
use strict;
use inc::Module::Install;

# Ugly parens are used in this Makefile.PL for backwards compatibility
# with some old dh-make-perl systems on Debian.

name(           'Finance-Quote');
all_from(       'lib/Finance/Quote.pm');
license(        'gpl');

# We'd like to have multiple authors listed.  See future_use below.

author('Paul Fenwick <pjf@cpan.org>');

=begin future_use

# Module::Install currently doesn't support multiple authors.
# When it does, the following may prove useful.

author(
    'Dj Padzensky <djpadz@padz.net>',
    'Linas Vepstas <linas@linas.org>',
    'Yannick LE NY <y-le-ny@ifrance.com>',
    'Paul Fenwick <pjf@cpan.org>',
    'Brent Neal <brentn@users.sourceforge.net>',
    'Volker Stuerzl <volker.stuerzl@gmx.de>',
    'Keith Refson <Keith.Refson#earth.ox.ac.uk>',
    'Rob Sessink <rob_ses@users.sourceforge.net>',
    'Leigh Wedding <leigh.wedding@telstra.com>',
    'Tobias Vancura <tvancura@altavista.net>',
    'James Treacy <treacy@debian.org>',
);

=end future_use

=cut

requires(       'LWP::UserAgent'            => 0);
requires(       'Crypt::SSLeay'             => 0);
requires(       'HTTP::Request::Common'     => 0);
requires(       'HTML::TableExtract'        => 0);
requires(       'HTML::TreeBuilder'         => 0);
requires(       'Web::Scraper'              => 0);

test_requires(  'Test::More'                => 0);

# Lowercase resource names have special meanings in the META.yml spec.

resources(      repository => 'http://github.com/pfenwick/finance-quote/');
resources(      bugtracker => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=Finance-Quote');
resources(      homepage   => 'http://finance-quote.sourceforge.net/');

# Uppercase resource names are not special in the spec.

resource(       MailingList => 'https://lists.sourceforge.net/lists/listinfo/finance-quote-devel');

# And we're done!

WriteAll();
