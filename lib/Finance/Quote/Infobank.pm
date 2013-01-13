#!/usr/bin/perl -w

#  Infobank.pm

package Finance::Quote::Infobank;
require 5.004;

use strict;
use POSIX qw(strftime);
use Encode 'from_to';

use vars qw($VERSION $INFOBANK_URL);

use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;

$VERSION = '0.1';

# URLs of where to obtain information.

$INFOBANK_URL =
("http://money.infobank.co.jp/InfoBank/ToshinKobetsu?ks=1&tcd=");

sub methods { return (infobank => \&infobank); }

{
    my @labels = qw/name price currency date/;
    sub labels { return (infobank => \@labels) }
}

#
# =======================================================================

sub infobank   {
    my $quoter = shift;
    my @symbols = @_;

    # Make sure symbols are requested
    ##CAN exit more gracefully - add later##

    return unless @symbols;

    # Local Variables
    my(%fundquote, $mutual);
    my($ua, $url, $reply, $ts, $row, $rowhd, $te, @rows, @ts);

    $ua = $quoter->user_agent;

    foreach (@symbols) {

	$mutual = $_;
	$url = "$INFOBANK_URL$mutual";
	$reply = $ua->request(GET $url);

	return unless ($reply->is_success);

	my $te_0 = new HTML::TableExtract(depth => 2, count => 0); # OK price
	my $te_1 = new HTML::TableExtract(depth => 2, count => 2); # OK unit 
	my $te_2 = new HTML::TableExtract(depth => 1, count => 1); # OK name
	my $te_3 = new HTML::TableExtract(depth => 1, count => 2); # OK date
	$te_0->parse($reply->content);
	$te_1->parse($reply->content);
	$te_2->parse($reply->content);
	$te_3->parse($reply->content);
	unless ( $te_0->tables > 0 )
	{
	    $fundquote {$mutual,"success"} = 0;
	    $fundquote {$mutual,"errormsg"} = "Fund name $mutual not found";
	    next;
	}

	my $name = $te_2->rows->[0][0];
	from_to($name, 'shift-jis', 'utf-8');
	$name =~ s/ +$//;
	$fundquote {$mutual, "name"} = $name;

	my $date = $te_3->rows->[3][2];
	$fundquote {$mutual, "date"} = $date;


	$te_1->rows->[4][1] =~ /(\d+)/;
	my $unit = $1;
	if ($unit == 0) {
	    $unit = 1;
	}
	$fundquote {$mutual, "unit"}  = $unit; 
	
	my $v = $te_0->rows->[0][1];
	$v =~ s/\,//g;
	$v =~ /(\d+)/;
	my $price = $1;
	my $tprice = $price/(10000/$unit);
	$fundquote {$mutual, "price"} = $tprice;

	# $quoter->store_date(\%fundquote, $mutual, {usdate => $$row[0]});

	$fundquote {$mutual, "symbol"} = $mutual;
	$fundquote {$mutual, "date"} = $date;
	$fundquote {$mutual, "currency"} = "JPY";
	$fundquote {$mutual, "method"} = "Infobank";
	
	# Assume things are fine here.
	$fundquote {$mutual, "success"} = 1;
    } #end symbols

    return %fundquote if wantarray;
    return \%fundquote;
}

1;

=head1 NAME

Finance::Quote::Infobank - Obtain mutual fund prices from
money.infobank.co.jp

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %kinfo = $q->fetch("infobunk","12345667A"); 

=head1 DESCRIPTION

This module obtains information about Japanese Mutual Fund prices from
L<http://money.infobank.co.jp/>.

=head1 FUNDLIB-CODE

..

=head1 LABELS RETURNED

The following labels may be retruned by Finance::Quote::Infobank:
symbol, name, date, price, currency.

=head1 SEE ALSO

Infobank website - L<http://money.infobank.co.jp/>

=head1 AUTHOR

TANIGUCHI Takaki 

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013, TANIGUCHI Takaki <takaki@asis.media-as.org>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 2 of the License, or
(at your option) any later version.


=cut
