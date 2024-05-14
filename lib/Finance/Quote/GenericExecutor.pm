#!/usr/bin/perl -w
#    This module is based on the Finance::Quote::YahooJSON module
#
#    The code has been writtem/modified by Kalpesh Patel to
#    retrieve stock information from Yahoo Finance Chart API call and 
#    parse through json
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

require 5.005;

use if DEBUG, 'Smart::Comments';
use strict;
use Inline Python => "Script";


# Note that we use $ENV{} since it can be passed transparently through GNC to F::Q module

#-## For *nix, call GNC as follows:
#-##   DEBUG=1 GENERIC_EXECUTOR=python GENERIC_FETCHER=<script> /usr/bin/gnucash <options1> <option2> ...
#=##
#-## To unset an env variable in *nixx, use unset. I. E., : 
#-##   unset DEBUG GENERIC_EXECUTOR GENERIC_FETCHER ...
#-##
#-## For Windows, call GNC as follows:
#-##   set DEBUG=1 & set GENERIC_EXECUTOR=<interpretor> & set GENERIC_FETCHER=<script> & "c:\Program Files (x86)\gnucash\bin\gnucash.exe" <options1> <option2> ...
#-##
#-## To unset an env variable in Windows, just leave out the value for the env variable. I. E., : 
#-##   set DEBUG= & set GENERIC_EXECUTOR= & ...
#-## 

package Finance::Quote::GenericExecutor;

# VERSION

sub methods {
    return (    run_executor => \&run_executor,
                genericexecutor => \&run_executor,
                usa => \&run_executor,
                nyse => \&run_executor,
                nasdaq => \&run_executor,
    );
}

{
    my @labels = qw/date isodate volume currency method exchange type
        open high low close nav price adjclose/;

    sub labels {
        return (    run_executor => \@labels,
                    GenericExecutor => \@labels,
                    usa => \@labels,
                    nyse => \@labels,
                    nasdaq => \@labels,
        );
    }
}

sub parameters {
  return ('EXECUTOR FETCHER');
}

sub run_executor {

    my $quoter = shift;
    my @stocks = @_;
    my ( %info );


    my $executor = exists $quoter->{module_specific_data}->{parameters}->{EXECUTOR}
                 ? $quoter->{module_specific_data}->{parameters}->{EXECUTOR}
                 : $ENV{"GENERIC_EXECUTOR"};

    my $script = exists $quoter->{module_specific_data}->{parameters}->{FETCHER}
                 ? $quoter->{module_specific_data}->{parameters}->{FETCHER}
                 : $ENV{"GENERIC_FETCHER"};

    if ( !defined $executor || !defined $script ) {
        foreach my $stock (@stocks) {
            $info{ $stock, 'success' } = 0;
            $info{ $stock, 'errormsg' } =
                    'A valid fetcher and a valid executor is required to retrieve quotes!';
        }
        return wantarray() ? %info : \%info;
        return \%info;
    }

    my $cmd = $executor . ' ' . $script . ' ' . join ('!', @stocks) . ' ' . '|';
    ### [<now>]   $cmd : $cmd

    open(my $output_stream, $cmd);

    my ($commodity);

    while (my $line = <$output_stream>) { # read the output from the execution
        chomp ($line); # get rid of CR/CR+LF if present
        foreach my $pair (split('!', $line)) { # break up input stream at ! markers and loop through it
            my ($lhs, $rhs) = split(':', $pair, 2); # split each pair into lhs and rhs of colon symbol

            ### [<now>]   $lhs : $lhs
            ### [<now>]   $rhs : $rhs

            if (defined($lhs)) { # Accept pair only if lhs is defined (ie is not blank)
                if ($lhs =~ m/ticker/i) { # if pair has "ticker" in lhs then injest pairs for that commodity going forward
                    $commodity = $rhs;
                } elsif (defined($commodity)) {
                    $info{ $commodity, $lhs } = $rhs;
                }
            }
            $info{ $commodity, 'errormsg' } = 'things are wrong';
            $info{ $commodity, 'success' } = 0;
  
        }

    }

    return wantarray() ? %info : \%info;
    return \%info;
}

1;

# testing: perl "c:\Program Files (x86)\gnucash\bin\gnc-fq-dump" -v run_executor BK FSPSX SBIN.NS

=head1 NAME

Finance::Quote::GenericExecutor - Obtain quotes from a external executor and a fetcher script.

=head1 SYNOPSIS

    use Finance::Quote;
    $q = Finance::Quote->new("GenericExecutor", details => {EXECUTOR => '...', FETCHER => '...'});
    %info = $q->fetch('run_executor', @ticker);

=head1 DESCRIPTION

This is a pass-thru bridge module between GNUCash and the local operating system.

This module fetches pricing information by invoking an OS accessible external executor (such as 
python, ruby or go language interpreter), a fetcher, such as a script passed to the executor, and 
capturing the standard output from the run to parse and return data from it. During the execution, 
enviornment is no way altered, thus must be pre-set.

The external program will be passed a single string containing all symbols concatenated with an 
explanation mark. Example:

  USDUSD=X!SUZLON.BO!RECLTD.NS!AMZN!SOLB.BR!^DJI!BEL20.BR!INGDIRECTFNE.BC!AENA.MC!CFR.JO

The external program is expected to return data in a stream format built up from pairs 
concatenated with exclamation mark ('!'). And two parts of each pair separated by a colon (':').
When the first part of a pair contains 'ticker', the second part denotes commodity name for which 
subsequent data pair is for. General template is as follows:

        ticker:<commodity1>!lhs1a:rhs1a!lhs1b:rhs1b!...!ticker:<commodity2>!lhs2a:rhs2a!lhs2b:rhs2b!...

Example for 'BK' and for 'BRK-B' symbol:

        ticker:BK!open:57.38999938964844!high:57.81999969482422!low:57.07500076293945
        !close:57.244998931884766!adjclose:57.244998931884766!volume:1745297!ticker:BRK-B
        !open:402.6600036621094!high:404.8699951171875!low:400.1099853515625!close:400.3999938964844
        !adjclose:400.3999938964844!volume:1753916!...

Standard output read by the module ignors blanks and encountering existing left hand side 
of the pair will replace previous one. 

=head1 LABELS RETURNED

Variable number of labels will be returned based upon information successfully retrieved. 

=head1 SEE ALSO

=cut
