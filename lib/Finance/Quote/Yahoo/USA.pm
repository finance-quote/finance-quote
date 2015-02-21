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
#    Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
#    02111-1307, USA
#
#
# This code derived from Padzensky's work on package Finance::YahooQuote,
# but extends its capabilites to encompas a greater number of data sources.
#
# This code was developed as part of GnuCash <http://www.gnucash.org/>

package Finance::Quote::Yahoo::USA;
require 5.005;

use strict;
use HTTP::Request::Common;
use LWP::UserAgent;
use Finance::Quote::Yahoo::Base qw/yahoo_request base_yahoo_labels/;

use vars qw/$YAHOO_URL %tiaacref_ids/;

# VERSION

# URLs of where to obtain information.

$YAHOO_URL = ("http://download.finance.yahoo.com/d/quotes.csv");

sub methods {return (canada   => \&yahoo,
                     usa      => \&yahoo,
		     yahoo    => \&yahoo,
		     nyse     => \&yahoo,
		     nasdaq   => \&yahoo,
		     vanguard => \&yahoo,
		     tiaacref => \&yahoo_tiaacref,
		     fidelity => \&yahoo_fidelity)};

{
	my @labels = (base_yahoo_labels(),"currency", "method");

	sub labels { return (canada	=> \@labels,
			     usa	=> \@labels,
			     yahoo	=> \@labels,
			     nyse	=> \@labels,
			     nasdaq	=> \@labels,
			     vanguard	=> \@labels,
			     tiaacref	=> [@labels,'name','nav'],
			     fidelity   => [@labels,'yield','nav']); }
}

# This is a special wrapper to provide information compatible with
# the primary Fidelity function of Finance::Quote.  It does a good
# job of a failover.
{

	# Really this list should be common for both the Fidelity.pm
	# and this module.  We could possibly get away with checking
	# for /XX$/, but I don't know how reliable that is.

	my %yield_funds = (FDRXX => 1,
	                   FDTXX => 1,
			   FGMXX => 1,
			   FRTXX => 1,
			   SPRXX => 1,
			   SPAXX => 1,
			   FDLXX => 1,
			   FGRXX => 1);

	sub yahoo_fidelity {
		my $quoter = shift;
		my @symbols = @_;
		return unless @symbols;

		# Call the normal yahoo function (defined later in this
		# file).

		my %info = yahoo($quoter,@symbols);

		foreach my $symbol (@symbols) {
			next unless $info{$symbol,"success"};
			if ($yield_funds{$symbol}) {
				$info{$symbol,"yield"}=$info{$symbol,"price"};
			} else {
				$info{$symbol,"nav"} = $info{$symbol,"price"};
			}
		}

		return wantarray ? %info : \%info;
	}
}

# This is a replacement for the old tiaacref module since Yahoo now provides
# quotes for TIAA/CREF and the old web site used by that module is forzen in time
# at 31 December 2014
{
	if (! %tiaacref_ids ) { #build a name hash for the annuities (once only)
		$tiaacref_ids{"CREFbond"} = "CREF Bond Market Account";
		$tiaacref_ids{"CREFequi"} = "CREF Equity Index Account";
		$tiaacref_ids{"CREFglob"} = "CREF Global Equities Account";
		$tiaacref_ids{"CREFgrow"} = "CREF Growth Account";
		$tiaacref_ids{"CREFinfb"} = "CREF Inflation-Linked Bond Account";
		$tiaacref_ids{"CREFmony"} = "CREF Money Market Account";
		$tiaacref_ids{"CREFsoci"} = "CREF Social Choice Account";
		$tiaacref_ids{"CREFstok"} = "CREF Stock Account";
		$tiaacref_ids{"TIAAreal"} = "TIAA Real Estate Account";
		$tiaacref_ids{"QCBMRX"} = "CREF Bond Market Account";
		$tiaacref_ids{"QCEQRX"} = "CREF Equity Index Account";
		$tiaacref_ids{"QCGLRX"} = "CREF Global Equities Account";
		$tiaacref_ids{"QCGRRX"} = "CREF Growth Account";
		$tiaacref_ids{"QCILRX"} = "CREF Inflation-Linked Bond Account";
		$tiaacref_ids{"QCMMRX"} = "CREF Money Market Account";
		$tiaacref_ids{"QCSCRX"} = "CREF Social Choice Account";
		$tiaacref_ids{"QCSTRX"} = "CREF Stock Account";
		$tiaacref_ids{"QREARX"} = "TIAA Real Estate Account";
		$tiaacref_ids{"TIDRX"} = "TIAA-CREF Bond Fund (Retirement)";
		$tiaacref_ids{"TBIRX"} = "TIAA-CREF Bond Index Fund (Retirement)";
		$tiaacref_ids{"TCBRX"} = "TIAA-CREF Bond Plus Fund (Retirement)";
		$tiaacref_ids{"TEMSX"} = "TIAA-CREF Emerging Markets Equity Fund (Retirement)";
		$tiaacref_ids{"TEQSX"} = "TIAA-CREF Emerging Markets Equity Index Fund (Retirement)";
		$tiaacref_ids{"TIQRX"} = "TIAA-CREF Equity Index Fund (Retirement)";
		$tiaacref_ids{"TNRRX"} = "TIAA-CREF Global Natural Resources Fund (Retirement)";
		$tiaacref_ids{"TRGIX"} = "TIAA-CREF Growth & Income Fund (Retirement)";
		$tiaacref_ids{"TIHRX"} = "TIAA-CREF High Yield Fund (Retirement)";
		$tiaacref_ids{"TIKRX"} = "TIAA-CREF Inflation-Linked Bond Fund (Retirement)";
		$tiaacref_ids{"TRERX"} = "TIAA-CREF International Equity Fund (Retirement)";
		$tiaacref_ids{"TRIEX"} = "TIAA-CREF International Equity Index Fund (Retirement)";
		$tiaacref_ids{"TILRX"} = "TIAA-CREF Large-Cap Growth Fund (Retirement)";
		$tiaacref_ids{"TRIRX"} = "TIAA-CREF Large-Cap Growth Index Fund (Retirement)";
		$tiaacref_ids{"TRLCX"} = "TIAA-CREF Large-Cap Value Fund (Retirement)";
		$tiaacref_ids{"TRCVX"} = "TIAA-CREF Large-Cap Value Index Fund (Retirement)";
		$tiaacref_ids{"TCLEX"} = "TIAA-CREF Lifecycle 2010 Fund (Retirement)";
		$tiaacref_ids{"TCLIX"} = "TIAA-CREF Lifecycle 2015 Fund (Retirement)";
		$tiaacref_ids{"TCLTX"} = "TIAA-CREF Lifecycle 2020 Fund (Retirement)";
		$tiaacref_ids{"TCLFX"} = "TIAA-CREF Lifecycle 2025 Fund (Retirement)";
		$tiaacref_ids{"TCLNX"} = "TIAA-CREF Lifecycle 2030 Fund (Retirement)";
		$tiaacref_ids{"TCLRX"} = "TIAA-CREF Lifecycle 2035 Fund (Retirement)";
		$tiaacref_ids{"TCLOX"} = "TIAA-CREF Lifecycle 2040 Fund (Retirement)";
		$tiaacref_ids{"TTFRX"} = "TIAA-CREF Lifecycle 2045 Fund (Retirement)";
		$tiaacref_ids{"TLFRX"} = "TIAA-CREF Lifecycle 2050 Fund (Retirement)";
		$tiaacref_ids{"TTRLX"} = "TIAA-CREF Lifecycle 2055 Fund (Retirement)";
		$tiaacref_ids{"TLTRX"} = "TIAA-CREF Lifecycle Index 2010 Fund (Retirement)";
		$tiaacref_ids{"TLGRX"} = "TIAA-CREF Lifecycle Index 2015 Fund (Retirement)";
		$tiaacref_ids{"TLWRX"} = "TIAA-CREF Lifecycle Index 2020 Fund (Retirement)";
		$tiaacref_ids{"TLQRX"} = "TIAA-CREF Lifecycle Index 2025 Fund (Retirement)";
		$tiaacref_ids{"TLHRX"} = "TIAA-CREF Lifecycle Index 2030 Fund (Retirement)";
		$tiaacref_ids{"TLYRX"} = "TIAA-CREF Lifecycle Index 2035 Fund (Retirement)";
		$tiaacref_ids{"TLZRX"} = "TIAA-CREF Lifecycle Index 2040 Fund (Retirement)";
		$tiaacref_ids{"TLMRX"} = "TIAA-CREF Lifecycle Index 2045 Fund (Retirement)";
		$tiaacref_ids{"TLLRX"} = "TIAA-CREF Lifecycle Index 2050 Fund (Retirement)";
		$tiaacref_ids{"TTIRX"} = "TIAA-CREF Lifecycle Index 2055 Fund (Retirement)";
		$tiaacref_ids{"TRCIX"} = "TIAA-CREF Lifecycle Index Retirement Income Fund (Retirement)";
		$tiaacref_ids{"TLIRX"} = "TIAA-CREF Lifecycle Retirement Income Fund (Retirement)";
		$tiaacref_ids{"TSARX"} = "TIAA-CREF Lifestyle Aggressive Growth Fund (Retirement)";
		$tiaacref_ids{"TSCTX"} = "TIAA-CREF Lifestyle Conservative Fund (Retirement)";
		$tiaacref_ids{"TSGRX"} = "TIAA-CREF Lifestyle Growth Fund (Retirement)";
		$tiaacref_ids{"TLSRX"} = "TIAA-CREF Lifestyle Income Fund (Retirement)";
		$tiaacref_ids{"TSMTX"} = "TIAA-CREF Lifestyle Moderate Fund (Retirement)";
		$tiaacref_ids{"TITRX"} = "TIAA-CREF Managed Allocation Fund (Retirement)";
		$tiaacref_ids{"TRGMX"} = "TIAA-CREF Mid-Cap Growth Fund (Retirement)";
		$tiaacref_ids{"TRVRX"} = "TIAA-CREF Mid-Cap Value Fund (Retirement)";
		$tiaacref_ids{"TIEXX"} = "TIAA-CREF Money Market Fund (Retirement)";
		$tiaacref_ids{"TRRSX"} = "TIAA-CREF Real Estate Securities Fund (Retirement)";
		$tiaacref_ids{"TRSPX"} = "TIAA-CREF S&P 500 Index Fund (Retirement)";
		$tiaacref_ids{"TISRX"} = "TIAA-CREF Short-Term Bond Fund (Retirement)";
		$tiaacref_ids{"TRBIX"} = "TIAA-CREF Small-Cap Blend Index Fund (Retirement)";
		$tiaacref_ids{"TRSEX"} = "TIAA-CREF Small-Cap Equity Fund (Retirement)";
		$tiaacref_ids{"TRSCX"} = "TIAA-CREF Social Choice Equity Fund (Retirement)";
		$tiaacref_ids{"TIBDX"} = "TIAA-CREF Bond Fund (Institutional)";
		$tiaacref_ids{"TBIIX"} = "TIAA-CREF Bond Index Fund (Institutional)";
		$tiaacref_ids{"TIBFX"} = "TIAA-CREF Bond Plus Fund (Institutional)";
		$tiaacref_ids{"TEMLX"} = "TIAA-CREF Emerging Markets Equity Fund (Institutional)";
		$tiaacref_ids{"TEQLX"} = "TIAA-CREF Emerging Markets Equity Index Fund (Institutional)";
		$tiaacref_ids{"TFIIX"} = "TIAA-CREF Enhanced International Equity Index Fund (Institutional)";
		$tiaacref_ids{"TLIIX"} = "TIAA-CREF Enhanced Large-Cap Growth Index Fund (Institutional)";
		$tiaacref_ids{"TEVIX"} = "TIAA-CREF Enhanced Large-Cap Value Index Fund (Institutional)";
		$tiaacref_ids{"TIEIX"} = "TIAA-CREF Equity Index Fund (Institutional)";
		$tiaacref_ids{"TNRIX"} = "TIAA-CREF Global Natural Resources Fund (Institutional)";
		$tiaacref_ids{"TIGRX"} = "TIAA-CREF Growth & Income Fund (Institutional)";
		$tiaacref_ids{"TIHYX"} = "TIAA-CREF High Yield Fund (Institutional)";
		$tiaacref_ids{"TIILX"} = "TIAA-CREF Inflation-Linked Bond Fund (Institutional)";
		$tiaacref_ids{"TIIEX"} = "TIAA-CREF International Equity Fund (Institutional)";
		$tiaacref_ids{"TCIEX"} = "TIAA-CREF International Equity Index Fund (Institutional)";
		$tiaacref_ids{"TILGX"} = "TIAA-CREF Large-Cap Growth Fund (Institutional)";
		$tiaacref_ids{"TILIX"} = "TIAA-CREF Large-Cap Growth Index Fund (Institutional)";
		$tiaacref_ids{"TRLIX"} = "TIAA-CREF Large-Cap Value Fund (Institutional)";
		$tiaacref_ids{"TILVX"} = "TIAA-CREF Large-Cap Value Index Fund (Institutional)";
		$tiaacref_ids{"TCTIX"} = "TIAA-CREF Lifecycle 2010 Fund (Institutional)";
		$tiaacref_ids{"TCNIX"} = "TIAA-CREF Lifecycle 2015 Fund (Institutional)";
		$tiaacref_ids{"TCWIX"} = "TIAA-CREF Lifecycle 2020 Fund (Institutional)";
		$tiaacref_ids{"TCYIX"} = "TIAA-CREF Lifecycle 2025 Fund (Institutional)";
		$tiaacref_ids{"TCRIX"} = "TIAA-CREF Lifecycle 2030 Fund (Institutional)";
		$tiaacref_ids{"TCIIX"} = "TIAA-CREF Lifecycle 2035 Fund (Institutional)";
		$tiaacref_ids{"TCOIX"} = "TIAA-CREF Lifecycle 2040 Fund (Institutional)";
		$tiaacref_ids{"TTFIX"} = "TIAA-CREF Lifecycle 2045 Fund (Institutional)";
		$tiaacref_ids{"TFTIX"} = "TIAA-CREF Lifecycle 2050 Fund (Institutional)";
		$tiaacref_ids{"TTRIX"} = "TIAA-CREF Lifecycle 2055 Fund (Institutional)";
		$tiaacref_ids{"TLTIX"} = "TIAA-CREF Lifecycle Index 2010 Fund (Institutional)";
		$tiaacref_ids{"TLFIX"} = "TIAA-CREF Lifecycle Index 2015 Fund (Institutional)";
		$tiaacref_ids{"TLWIX"} = "TIAA-CREF Lifecycle Index 2020 Fund (Institutional)";
		$tiaacref_ids{"TLQIX"} = "TIAA-CREF Lifecycle Index 2025 Fund (Institutional)";
		$tiaacref_ids{"TLHIX"} = "TIAA-CREF Lifecycle Index 2030 Fund (Institutional)";
		$tiaacref_ids{"TLYIX"} = "TIAA-CREF Lifecycle Index 2035 Fund (Institutional)";
		$tiaacref_ids{"TLZIX"} = "TIAA-CREF Lifecycle Index 2040 Fund (Institutional)";
		$tiaacref_ids{"TLXIX"} = "TIAA-CREF Lifecycle Index 2045 Fund (Institutional)";
		$tiaacref_ids{"TLLIX"} = "TIAA-CREF Lifecycle Index 2050 Fund (Institutional)";
		$tiaacref_ids{"TTIIX"} = "TIAA-CREF Lifecycle Index 2055 Fund (Institutional)";
		$tiaacref_ids{"TRILX"} = "TIAA-CREF Lifecycle Index Retirement Income Fund (Institutional)";
		$tiaacref_ids{"TLRIX"} = "TIAA-CREF Lifecycle Retirement Income Fund (Institutional)";
		$tiaacref_ids{"TSAIX"} = "TIAA-CREF Lifestyle Aggressive Growth Fund (Institutional)";
		$tiaacref_ids{"TCSIX"} = "TIAA-CREF Lifestyle Conservative Fund (Institutional)";
		$tiaacref_ids{"TSGGX"} = "TIAA-CREF Lifestyle Growth Fund (Institutional)";
		$tiaacref_ids{"TSITX"} = "TIAA-CREF Lifestyle Income Fund (Institutional)";
		$tiaacref_ids{"TSIMX"} = "TIAA-CREF Lifestyle Moderate Fund (Institutional)";
		$tiaacref_ids{"TIMIX"} = "TIAA-CREF Managed Allocation Fund (Institutional)";
		$tiaacref_ids{"TRPWX"} = "TIAA-CREF Mid-Cap Growth Fund (Institutional)";
		$tiaacref_ids{"TIMVX"} = "TIAA-CREF Mid-Cap Value Fund (Institutional)";
		$tiaacref_ids{"TCIXX"} = "TIAA-CREF Money Market Fund (Institutional)";
		$tiaacref_ids{"TIREX"} = "TIAA-CREF Real Estate Securities Fund (Institutional)";
		$tiaacref_ids{"TISPX"} = "TIAA-CREF S&P 500 Index Fund (Institutional)";
		$tiaacref_ids{"TISIX"} = "TIAA-CREF Short-Term Bond Fund (Institutional)";
		$tiaacref_ids{"TISBX"} = "TIAA-CREF Small-Cap Blend Index Fund (Institutional)";
		$tiaacref_ids{"TISEX"} = "TIAA-CREF Small-Cap Equity Fund (Institutional)";
		$tiaacref_ids{"TISCX"} = "TIAA-CREF Social Choice Equity Fund (Institutional)";
		$tiaacref_ids{"TITIX"} = "TIAA-CREF Tax-Exempt Bond Fund (Institutional)";
		$tiaacref_ids{"TIORX"} = "TIAA-CREF Bond Fund (Retail)";
		$tiaacref_ids{"TBILX"} = "TIAA-CREF Bond Index Fund (Retail)";
		$tiaacref_ids{"TCBPX"} = "TIAA-CREF Bond Plus Fund (Retail)";
		$tiaacref_ids{"TEMRX"} = "TIAA-CREF Emerging Markets Equity Fund (Retail)";
		$tiaacref_ids{"TEQKX"} = "TIAA-CREF Emerging Markets Equity Index Fund (Retail)";
		$tiaacref_ids{"TINRX"} = "TIAA-CREF Equity Index Fund (Retail)";
		$tiaacref_ids{"TNRLX"} = "TIAA-CREF Global Natural Resources Fund (Retail)";
		$tiaacref_ids{"TIIRX"} = "TIAA-CREF Growth & Income Fund (Retail)";
		$tiaacref_ids{"TIYRX"} = "TIAA-CREF High Yield Fund (Retail)";
		$tiaacref_ids{"TCILX"} = "TIAA-CREF Inflation-Linked Bond Fund (Retail)";
		$tiaacref_ids{"TIERX"} = "TIAA-CREF International Equity Fund (Retail)";
		$tiaacref_ids{"TIRTX"} = "TIAA-CREF Large-Cap Growth Fund (Retail)";
		$tiaacref_ids{"TCLCX"} = "TIAA-CREF Large-Cap Value Fund (Retail)";
		$tiaacref_ids{"TLRRX"} = "TIAA-CREF Lifecycle Retirement Income Fund (Retail)";
		$tiaacref_ids{"TSALX"} = "TIAA-CREF Lifestyle Aggressive Growth Fund (Retail)";
		$tiaacref_ids{"TSCLX"} = "TIAA-CREF Lifestyle Conservative Fund (Retail)";
		$tiaacref_ids{"TSGLX"} = "TIAA-CREF Lifestyle Growth Fund (Retail)";
		$tiaacref_ids{"TSILX"} = "TIAA-CREF Lifestyle Income Fund (Retail)";
		$tiaacref_ids{"TSMLX"} = "TIAA-CREF Lifestyle Moderate Fund (Retail)";
		$tiaacref_ids{"TIMRX"} = "TIAA-CREF Managed Allocation Fund (Retail)";
		$tiaacref_ids{"TCMGX"} = "TIAA-CREF Mid-Cap Growth Fund (Retail)";
		$tiaacref_ids{"TCMVX"} = "TIAA-CREF Mid-Cap Value Fund (Retail)";
		$tiaacref_ids{"TIRXX"} = "TIAA-CREF Money Market Fund (Retail)";
		$tiaacref_ids{"TCREX"} = "TIAA-CREF Real Estate Securities Fund (Retail)";
		$tiaacref_ids{"TCTRX"} = "TIAA-CREF Short-Term Bond Fund (Retail)";
		$tiaacref_ids{"TCSEX"} = "TIAA-CREF Small-Cap Equity Fund (Retail)";
		$tiaacref_ids{"TICRX"} = "TIAA-CREF Social Choice Equity Fund (Retail)";
		$tiaacref_ids{"TIXRX"} = "TIAA-CREF Tax-Exempt Bond Fund (Retail)";
		$tiaacref_ids{"TIDPX"} = "TIAA-CREF Bond Fund (Premier)";
		$tiaacref_ids{"TBIPX"} = "TIAA-CREF Bond Index Fund (Premier)";
		$tiaacref_ids{"TBPPX"} = "TIAA-CREF Bond Plus Fund (Premier)";
		$tiaacref_ids{"TEMPX"} = "TIAA-CREF Emerging Markets Equity Fund (Premier)";
		$tiaacref_ids{"TEQPX"} = "TIAA-CREF Emerging Markets Equity Index Fund (Premier)";
		$tiaacref_ids{"TCEPX"} = "TIAA-CREF Equity Index Fund (Premier)";
		$tiaacref_ids{"TNRPX"} = "TIAA-CREF Global Natural Resources Fund (Premier)";
		$tiaacref_ids{"TRPGX"} = "TIAA-CREF Growth & Income Fund (Premier)";
		$tiaacref_ids{"TIHPX"} = "TIAA-CREF High Yield Fund (Premier)";
		$tiaacref_ids{"TIKPX"} = "TIAA-CREF Inflation-Linked Bond Fund (Premier)";
		$tiaacref_ids{"TREPX"} = "TIAA-CREF International Equity Fund (Premier)";
		$tiaacref_ids{"TRIPX"} = "TIAA-CREF International Equity Index Fund (Premier)";
		$tiaacref_ids{"TILPX"} = "TIAA-CREF Large-Cap Growth Fund (Premier)";
		$tiaacref_ids{"TRCPX"} = "TIAA-CREF Large-Cap Value Fund (Premier)";
		$tiaacref_ids{"TCTPX"} = "TIAA-CREF Lifecycle 2010 Fund (Premier)";
		$tiaacref_ids{"TCFPX"} = "TIAA-CREF Lifecycle 2015 Fund (Premier)";
		$tiaacref_ids{"TCWPX"} = "TIAA-CREF Lifecycle 2020 Fund (Premier)";
		$tiaacref_ids{"TCQPX"} = "TIAA-CREF Lifecycle 2025 Fund (Premier)";
		$tiaacref_ids{"TCHPX"} = "TIAA-CREF Lifecycle 2030 Fund (Premier)";
		$tiaacref_ids{"TCYPX"} = "TIAA-CREF Lifecycle 2035 Fund (Premier)";
		$tiaacref_ids{"TCZPX"} = "TIAA-CREF Lifecycle 2040 Fund (Premier)";
		$tiaacref_ids{"TTFPX"} = "TIAA-CREF Lifecycle 2045 Fund (Premier)";
		$tiaacref_ids{"TCLPX"} = "TIAA-CREF Lifecycle 2050 Fund (Premier)";
		$tiaacref_ids{"TTRPX"} = "TIAA-CREF Lifecycle 2055 Fund (Premier)";
		$tiaacref_ids{"TLTPX"} = "TIAA-CREF Lifecycle Index 2010 Fund (Premier)";
		$tiaacref_ids{"TLFPX"} = "TIAA-CREF Lifecycle Index 2015 Fund (Premier)";
		$tiaacref_ids{"TLWPX"} = "TIAA-CREF Lifecycle Index 2020 Fund (Premier)";
		$tiaacref_ids{"TLVPX"} = "TIAA-CREF Lifecycle Index 2025 Fund (Premier)";
		$tiaacref_ids{"TLHPX"} = "TIAA-CREF Lifecycle Index 2030 Fund (Premier)";
		$tiaacref_ids{"TLYPX"} = "TIAA-CREF Lifecycle Index 2035 Fund (Premier)";
		$tiaacref_ids{"TLPRX"} = "TIAA-CREF Lifecycle Index 2040 Fund (Premier)";
		$tiaacref_ids{"TLMPX"} = "TIAA-CREF Lifecycle Index 2045 Fund (Premier)";
		$tiaacref_ids{"TLLPX"} = "TIAA-CREF Lifecycle Index 2050 Fund (Premier)";
		$tiaacref_ids{"TTIPX"} = "TIAA-CREF Lifecycle Index 2055 Fund (Premier)";
		$tiaacref_ids{"TLIPX"} = "TIAA-CREF Lifecycle Index Retirement Income Fund (Premier)";
		$tiaacref_ids{"TPILX"} = "TIAA-CREF Lifecycle Retirement Income Fund (Premier)";
		$tiaacref_ids{"TSAPX"} = "TIAA-CREF Lifestyle Aggressive Growth Fund (Premier)";
		$tiaacref_ids{"TLSPX"} = "TIAA-CREF Lifestyle Conservative Fund (Premier)";
		$tiaacref_ids{"TSGPX"} = "TIAA-CREF Lifestyle Growth Fund (Premier)";
		$tiaacref_ids{"TSIPX"} = "TIAA-CREF Lifestyle Income Fund (Premier)";
		$tiaacref_ids{"TSMPX"} = "TIAA-CREF Lifestyle Moderate Fund (Premier)";
		$tiaacref_ids{"TRGPX"} = "TIAA-CREF Mid-Cap Growth Fund (Premier)";
		$tiaacref_ids{"TRVPX"} = "TIAA-CREF Mid-Cap Value Fund (Premier)";
		$tiaacref_ids{"TPPXX"} = "TIAA-CREF Money Market Fund (Premier)";
		$tiaacref_ids{"TRRPX"} = "TIAA-CREF Real Estate Securities Fund (Premier)";
		$tiaacref_ids{"TSTPX"} = "TIAA-CREF Short-Term Bond Fund (Premier)";
		$tiaacref_ids{"TSRPX"} = "TIAA-CREF Small-Cap Equity Fund (Premier)";
		$tiaacref_ids{"TRPSX"} = "TIAA-CREF Social Choice Equity Fund (Premier)";
	}

	# The old tiaacref module used fake symbols for some funds.  This
	# array maps them to the ones used by Yahoo
	my %sym_map;
	$sym_map{"crefbond"} = "QCBMRX";
	$sym_map{"crefequi"} = "QCEQRX";
	$sym_map{"crefglob"} = "QCGLRX";
	$sym_map{"crefgrow"} = "QCGRRX";
	$sym_map{"crefinfb"} = "QCILRX";
	$sym_map{"crefmony"} = "QCMMRX";
	$sym_map{"crefsoci"} = "QCSCRX";
	$sym_map{"crefstok"} = "QCSTRX";
	$sym_map{"tiaareal"} = "QREARX";
	#  And reverse map
	my %old_sym;

	sub yahoo_tiaacref {
		my $quoter = shift;
		my @symbols = @_;
		my @newsyms = ();
		return unless @symbols;

		# Map the old symbols to the Yahoo ones
		foreach my $sym (@symbols) {
			my $lcsym = $sym;
			$lcsym =~ tr/A-Z/a-z/;
			if (defined($sym_map{$lcsym})) {
				my $newsym = $sym_map{$lcsym};
				push(@newsyms, $newsym);
				$newsym =~ tr/A-Z/a-z/;
				$old_sym{$newsym} = $sym;
			} else {
				push(@newsyms, $sym);
				$old_sym{$lcsym} = $sym;
			}
		}

		# Call the normal yahoo function (defined later in this file).
		my %info = yahoo($quoter,@newsyms);

		my %retval;
		# Map the results back to the  old symbols
		foreach my $keyname (keys %info) {
			my ($sym, $attr) = split('\034', $keyname);
			my  $lcsym = $sym;
			$lcsym =~ tr/A-Z/a-z/;
			if (defined($old_sym{$lcsym})) {
				if ($attr eq "symbol") {
					$retval{$old_sym{$lcsym}, "symbol"} = $old_sym{$lcsym};
					$retval{$old_sym{$lcsym}, "name"} = $tiaacref_ids{$old_sym{$lcsym}};
				} elsif ($attr eq "price") {
					$retval{$old_sym{$lcsym}, "price"} = $info{$sym, "price"};
					$retval{$old_sym{$lcsym}, "nav"} = $info{$sym, "price"};
				} elsif ($attr eq "method") {
					$retval{$old_sym{$lcsym}, "method"} = "tiaacref";
				} else {
					$retval{$old_sym{$lcsym}, $attr} = $info{$sym, $attr};
				}
			}
		}

		return wantarray ? %retval : \%retval;
	}
}

sub yahoo
{
	my $quoter = shift;
	my @symbols = @_;
	return unless @symbols;	# Nothing if no symbols.

	# This does all the hard work.
	my %info = yahoo_request($quoter,$YAHOO_URL,\@symbols);

	foreach my $symbol (@symbols) {
		next unless $info{$symbol,"success"};
		$info{$symbol,"method"} = "yahoo";
	}
	return %info if wantarray;
	return \%info;
}

1;

=head1 NAME

Finance::Quote::Yahoo::USA - Obtain information about stocks and funds
in the USA and Canada.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = $q->fetch("usa","SGI");

=head1 DESCRIPTION

This method provides access to financial information from a number
of exhcanges in the United States and Canada.  The following methods
are available:

	canada
	usa
	yahoo
	nyse
	nasdaq
	vanguard
	fidelity
	tiaacref

These methods all use the same information source, and hence can
be considered somewhat interchangable.  However, the method "yahoo"
should be passed to fetch if you wish to obtain information
from any source that Yahoo tracks.

This method is loaded by default by Finance::Quote, although it
can be explicitly loaded by passing the argument "Yahoo::USA"
to Finance::Quote->new().

Information returned by this module may be subject to Yahoo's
terms and conditions.  See http://finance.yahoo.com/ for more
information.

=head1 LABELS RETURNED

This module returns all the standard labels that Yahoo provides,
as well as the currency label.  See Finance::Quote::Yahoo::Base
for more information.

=head1 TIAACREF SYMBOLS

The following symbols can be used with the tiaacref method

    CREF Bond Market Account:                                   CREFbond or QCBMRX
    CREF Equity Index Account:                                  CREFequi or QCEQRX
    CREF Global Equities Account:                               CREFglob or QCGLRX
    CREF Growth Account:                                        CREFgrow or QCGRRX
    CREF Inflation-Linked Bond Account:                         CREFinfb or QCILRX
    CREF Money Market Account:                                  CREFmony or QCMMRX
    CREF Social Choice Account:                                 CREFsoci or QCSCRX
    CREF Stock Account:                                         CREFstok or QCSTRX
    TIAA Real Estate Account:                                   TIAAreal or QREARX
    TIAA-CREF Bond Fund (Retirement):                           TIDRX
    TIAA-CREF Bond Index Fund (Retirement):                     TBIRX
    TIAA-CREF Bond Plus Fund (Retirement):                      TCBRX
    TIAA-CREF Emerging Markets Equity Fund (Retirement):        TEMSX
    TIAA-CREF Emerging Markets Equity Index Fund (Retirement): TEQSX
    TIAA-CREF Equity Index Fund (Retirement):                   TIQRX
    TIAA-CREF Global Natural Resources Fund (Retirement):       TNRRX
    TIAA-CREF Growth & Income Fund (Retirement):                TRGIX
    TIAA-CREF High Yield Fund (Retirement):                     TIHRX
    TIAA-CREF Inflation-Linked Bond Fund (Retirement):          TIKRX
    TIAA-CREF International Equity Fund (Retirement):           TRERX
    TIAA-CREF International Equity Index Fund (Retirement):     TRIEX
    TIAA-CREF Large-Cap Growth Fund (Retirement):               TILRX
    TIAA-CREF Large-Cap Growth Index Fund (Retirement):         TRIRX
    TIAA-CREF Large-Cap Value Fund (Retirement):                TRLCX
    TIAA-CREF Large-Cap Value Index Fund (Retirement):          TRCVX
    TIAA-CREF Lifecycle 2010 Fund (Retirement):                 TCLEX
    TIAA-CREF Lifecycle 2015 Fund (Retirement):                 TCLIX
    TIAA-CREF Lifecycle 2020 Fund (Retirement):                 TCLTX
    TIAA-CREF Lifecycle 2025 Fund (Retirement):                 TCLFX
    TIAA-CREF Lifecycle 2030 Fund (Retirement):                 TCLNX
    TIAA-CREF Lifecycle 2035 Fund (Retirement):                 TCLRX
    TIAA-CREF Lifecycle 2040 Fund (Retirement):                 TCLOX
    TIAA-CREF Lifecycle 2045 Fund (Retirement):                 TTFRX
    TIAA-CREF Lifecycle 2050 Fund (Retirement):                 TLFRX
    TIAA-CREF Lifecycle 2055 Fund (Retirement):                 TTRLX
    TIAA-CREF Lifecycle Index 2010 Fund (Retirement):           TLTRX
    TIAA-CREF Lifecycle Index 2015 Fund (Retirement):           TLGRX
    TIAA-CREF Lifecycle Index 2020 Fund (Retirement):           TLWRX
    TIAA-CREF Lifecycle Index 2025 Fund (Retirement):           TLQRX
    TIAA-CREF Lifecycle Index 2030 Fund (Retirement):           TLHRX
    TIAA-CREF Lifecycle Index 2035 Fund (Retirement):           TLYRX
    TIAA-CREF Lifecycle Index 2040 Fund (Retirement):           TLZRX
    TIAA-CREF Lifecycle Index 2045 Fund (Retirement):           TLMRX
    TIAA-CREF Lifecycle Index 2050 Fund (Retirement):           TLLRX
    TIAA-CREF Lifecycle Index 2055 Fund (Retirement):           TTIRX
    TIAA-CREF Lifecycle Index Retirement Income Fund (Retirement): TRCIX
    TIAA-CREF Lifecycle Retirement Income Fund (Retirement):    TLIRX
    TIAA-CREF Lifestyle Aggressive Growth Fund (Retirement):    TSARX
    TIAA-CREF Lifestyle Conservative Fund (Retirement):         TSCTX
    TIAA-CREF Lifestyle Growth Fund (Retirement):               TSGRX
    TIAA-CREF Lifestyle Income Fund (Retirement):               TLSRX
    TIAA-CREF Lifestyle Moderate Fund (Retirement):             TSMTX
    TIAA-CREF Managed Allocation Fund (Retirement):             TITRX
    TIAA-CREF Mid-Cap Growth Fund (Retirement):                 TRGMX
    TIAA-CREF Mid-Cap Value Fund (Retirement):                  TRVRX
    TIAA-CREF Money Market Fund (Retirement):                   TIEXX
    TIAA-CREF Real Estate Securities Fund (Retirement):         TRRSX
    TIAA-CREF S&P 500 Index Fund (Retirement):                  TRSPX
    TIAA-CREF Short-Term Bond Fund (Retirement):                TISRX
    TIAA-CREF Small-Cap Blend Index Fund (Retirement):          TRBIX
    TIAA-CREF Small-Cap Equity Fund (Retirement):               TRSEX
    TIAA-CREF Social Choice Equity Fund (Retirement):           TRSCX
    TIAA-CREF Bond Fund (Institutional):                        TIBDX
    TIAA-CREF Bond Index Fund (Institutional):                  TBIIX
    TIAA-CREF Bond Plus Fund (Institutional):                   TIBFX
    TIAA-CREF Emerging Markets Equity Fund (Institutional):     TEMLX
    TIAA-CREF Emerging Markets Equity Index Fund (Institutional): TEQLX
    TIAA-CREF Enhanced International Equity Index Fund (Institutional): TFIIX
    TIAA-CREF Enhanced Large-Cap Growth Index Fund (Institutional): TLIIX
    TIAA-CREF Enhanced Large-Cap Value Index Fund (Institutional): TEVIX
    TIAA-CREF Equity Index Fund (Institutional):                TIEIX
    TIAA-CREF Global Natural Resources Fund (Institutional):    TNRIX
    TIAA-CREF Growth & Income Fund (Institutional):             TIGRX
    TIAA-CREF High Yield Fund (Institutional):                  TIHYX
    TIAA-CREF Inflation-Linked Bond Fund (Institutional):       TIILX
    TIAA-CREF International Equity Fund (Institutional):        TIIEX
    TIAA-CREF International Equity Index Fund (Institutional):  TCIEX
    TIAA-CREF Large-Cap Growth Fund (Institutional):            TILGX
    TIAA-CREF Large-Cap Growth Index Fund (Institutional):      TILIX
    TIAA-CREF Large-Cap Value Fund (Institutional):             TRLIX
    TIAA-CREF Large-Cap Value Index Fund (Institutional):       TILVX
    TIAA-CREF Lifecycle 2010 Fund (Institutional):              TCTIX
    TIAA-CREF Lifecycle 2015 Fund (Institutional):              TCNIX
    TIAA-CREF Lifecycle 2020 Fund (Institutional):              TCWIX
    TIAA-CREF Lifecycle 2025 Fund (Institutional):              TCYIX
    TIAA-CREF Lifecycle 2030 Fund (Institutional):              TCRIX
    TIAA-CREF Lifecycle 2035 Fund (Institutional):              TCIIX
    TIAA-CREF Lifecycle 2040 Fund (Institutional):              TCOIX
    TIAA-CREF Lifecycle 2045 Fund (Institutional):              TTFIX
    TIAA-CREF Lifecycle 2050 Fund (Institutional):              TFTIX
    TIAA-CREF Lifecycle 2055 Fund (Institutional):              TTRIX
    TIAA-CREF Lifecycle Index 2010 Fund (Institutional):        TLTIX
    TIAA-CREF Lifecycle Index 2015 Fund (Institutional):        TLFIX
    TIAA-CREF Lifecycle Index 2020 Fund (Institutional):        TLWIX
    TIAA-CREF Lifecycle Index 2025 Fund (Institutional):        TLQIX
    TIAA-CREF Lifecycle Index 2030 Fund (Institutional):        TLHIX
    TIAA-CREF Lifecycle Index 2035 Fund (Institutional):        TLYIX
    TIAA-CREF Lifecycle Index 2040 Fund (Institutional):        TLZIX
    TIAA-CREF Lifecycle Index 2045 Fund (Institutional):        TLXIX
    TIAA-CREF Lifecycle Index 2050 Fund (Institutional):        TLLIX
    TIAA-CREF Lifecycle Index 2055 Fund (Institutional):        TTIIX
    TIAA-CREF Lifecycle Index Retirement Income Fund (Institutional): TRILX
    TIAA-CREF Lifecycle Retirement Income Fund (Institutional): TLRIX
    TIAA-CREF Lifestyle Aggressive Growth Fund (Institutional): TSAIX
    TIAA-CREF Lifestyle Conservative Fund (Institutional):      TCSIX
    TIAA-CREF Lifestyle Growth Fund (Institutional):            TSGGX
    TIAA-CREF Lifestyle Income Fund (Institutional):            TSITX
    TIAA-CREF Lifestyle Moderate Fund (Institutional):          TSIMX
    TIAA-CREF Managed Allocation Fund (Institutional):          TIMIX
    TIAA-CREF Mid-Cap Growth Fund (Institutional):              TRPWX
    TIAA-CREF Mid-Cap Value Fund (Institutional):               TIMVX
    TIAA-CREF Money Market Fund (Institutional):                TCIXX
    TIAA-CREF Real Estate Securities Fund (Institutional):      TIREX
    TIAA-CREF S&P 500 Index Fund (Institutional):               TISPX
    TIAA-CREF Short-Term Bond Fund (Institutional):             TISIX
    TIAA-CREF Small-Cap Blend Index Fund (Institutional):       TISBX
    TIAA-CREF Small-Cap Equity Fund (Institutional):            TISEX
    TIAA-CREF Social Choice Equity Fund (Institutional):        TISCX
    TIAA-CREF Tax-Exempt Bond Fund (Institutional):             TITIX
    TIAA-CREF Bond Fund (Retail):                               TIORX
    TIAA-CREF Bond Index Fund (Retail):                         TBILX
    TIAA-CREF Bond Plus Fund (Retail):                          TCBPX
    TIAA-CREF Emerging Markets Equity Fund (Retail):            TEMRX
    TIAA-CREF Emerging Markets Equity Index Fund (Retail):      TEQKX
    TIAA-CREF Equity Index Fund (Retail):                       TINRX
    TIAA-CREF Global Natural Resources Fund (Retail):           TNRLX
    TIAA-CREF Growth & Income Fund (Retail):                    TIIRX
    TIAA-CREF High Yield Fund (Retail):                         TIYRX
    TIAA-CREF Inflation-Linked Bond Fund (Retail):              TCILX
    TIAA-CREF International Equity Fund (Retail):               TIERX
    TIAA-CREF Large-Cap Growth Fund (Retail):                   TIRTX
    TIAA-CREF Large-Cap Value Fund (Retail):                    TCLCX
    TIAA-CREF Lifecycle Retirement Income Fund (Retail):        TLRRX
    TIAA-CREF Lifestyle Aggressive Growth Fund (Retail):        TSALX
    TIAA-CREF Lifestyle Conservative Fund (Retail):             TSCLX
    TIAA-CREF Lifestyle Growth Fund (Retail):                   TSGLX
    TIAA-CREF Lifestyle Income Fund (Retail):                   TSILX
    TIAA-CREF Lifestyle Moderate Fund (Retail):                 TSMLX
    TIAA-CREF Managed Allocation Fund (Retail):                 TIMRX
    TIAA-CREF Mid-Cap Growth Fund (Retail):                     TCMGX
    TIAA-CREF Mid-Cap Value Fund (Retail):                      TCMVX
    TIAA-CREF Money Market Fund (Retail):                       TIRXX
    TIAA-CREF Real Estate Securities Fund (Retail):             TCREX
    TIAA-CREF Short-Term Bond Fund (Retail):                    TCTRX
    TIAA-CREF Small-Cap Equity Fund (Retail):                   TCSEX
    TIAA-CREF Social Choice Equity Fund (Retail):               TICRX
    TIAA-CREF Tax-Exempt Bond Fund (Retail):                    TIXRX
    TIAA-CREF Bond Fund (Premier):                              TIDPX
    TIAA-CREF Bond Index Fund (Premier):                        TBIPX
    TIAA-CREF Bond Plus Fund (Premier):                         TBPPX
    TIAA-CREF Emerging Markets Equity Fund (Premier):           TEMPX
    TIAA-CREF Emerging Markets Equity Index Fund (Premier):     TEQPX
    TIAA-CREF Equity Index Fund (Premier):                      TCEPX
    TIAA-CREF Global Natural Resources Fund (Premier):          TNRPX
    TIAA-CREF Growth & Income Fund (Premier):                   TRPGX
    TIAA-CREF High Yield Fund (Premier):                        TIHPX
    TIAA-CREF Inflation-Linked Bond Fund (Premier):             TIKPX
    TIAA-CREF International Equity Fund (Premier):              TREPX
    TIAA-CREF International Equity Index Fund (Premier):        TRIPX
    TIAA-CREF Large-Cap Growth Fund (Premier):                  TILPX
    TIAA-CREF Large-Cap Value Fund (Premier):                   TRCPX
    TIAA-CREF Lifecycle 2010 Fund (Premier):                    TCTPX
    TIAA-CREF Lifecycle 2015 Fund (Premier):                    TCFPX
    TIAA-CREF Lifecycle 2020 Fund (Premier):                    TCWPX
    TIAA-CREF Lifecycle 2025 Fund (Premier):                    TCQPX
    TIAA-CREF Lifecycle 2030 Fund (Premier):                    TCHPX
    TIAA-CREF Lifecycle 2035 Fund (Premier):                    TCYPX
    TIAA-CREF Lifecycle 2040 Fund (Premier):                    TCZPX
    TIAA-CREF Lifecycle 2045 Fund (Premier):                    TTFPX
    TIAA-CREF Lifecycle 2050 Fund (Premier):                    TCLPX
    TIAA-CREF Lifecycle 2055 Fund (Premier):                    TTRPX
    TIAA-CREF Lifecycle Index 2010 Fund (Premier):              TLTPX
    TIAA-CREF Lifecycle Index 2015 Fund (Premier):              TLFPX
    TIAA-CREF Lifecycle Index 2020 Fund (Premier):              TLWPX
    TIAA-CREF Lifecycle Index 2025 Fund (Premier):              TLVPX
    TIAA-CREF Lifecycle Index 2030 Fund (Premier):              TLHPX
    TIAA-CREF Lifecycle Index 2035 Fund (Premier):              TLYPX
    TIAA-CREF Lifecycle Index 2040 Fund (Premier):              TLPRX
    TIAA-CREF Lifecycle Index 2045 Fund (Premier):              TLMPX
    TIAA-CREF Lifecycle Index 2050 Fund (Premier):              TLLPX
    TIAA-CREF Lifecycle Index 2055 Fund (Premier):              TTIPX
    TIAA-CREF Lifecycle Index Retirement Income Fund (Premier): TLIPX
    TIAA-CREF Lifecycle Retirement Income Fund (Premier):       TPILX
    TIAA-CREF Lifestyle Aggressive Growth Fund (Premier):       TSAPX
    TIAA-CREF Lifestyle Conservative Fund (Premier):            TLSPX
    TIAA-CREF Lifestyle Growth Fund (Premier):                  TSGPX
    TIAA-CREF Lifestyle Income Fund (Premier):                  TSIPX
    TIAA-CREF Lifestyle Moderate Fund (Premier):                TSMPX
    TIAA-CREF Mid-Cap Growth Fund (Premier):                    TRGPX
    TIAA-CREF Mid-Cap Value Fund (Premier):                     TRVPX
    TIAA-CREF Money Market Fund (Premier):                      TPPXX
    TIAA-CREF Real Estate Securities Fund (Premier):            TRRPX
    TIAA-CREF Short-Term Bond Fund (Premier):                   TSTPX
    TIAA-CREF Small-Cap Equity Fund (Premier):                  TSRPX
    TIAA-CREF Social Choice Equity Fund (Premier):              TRPSX

=head1 BUGS

Yahoo does not make a distinction between the various exchanges
in the United States and Canada.  For example, it is possible to request
a stock using the "NYSE" method and still obtain data even if that stock
does not exist on the NYSE but exists on a different exchange.

=head1 SEE ALSO

Yahoo Finance, http://finance.yahoo.com/

Finance::Quote::Yahoo::Base

=cut
