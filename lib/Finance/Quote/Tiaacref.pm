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

package Finance::Quote::Tiaacref;
require 5.005;
require Crypt::SSLeay;
require Mozilla::CA;

use strict;

use vars qw($VERSION $CREF_URL $TIAA_URL
			%tiaacref_ids %tiaacref_locs %tiaacref_vals);

use LWP::UserAgent;
use HTTP::Request::Common;
use Carp;
use Encode;

$VERSION = '1.20' ;

# URLs of where to obtain information.
# This used to be different for the CREF and TIAA annuities, but this changed.
$CREF_URL = ("https://www.tiaa-cref.org/public/tcfpi/Export/InvestmentDetails?Details=DailyPerformance");

sub methods { return (tiaacref=>\&tiaacref); }

sub labels { return (tiaacref => [qw/method symbol exchange name date isodate nav price/]); }

# =======================================================================
# TIAA-CREF Annuities are not listed on any exchange, unlike their mutual funds
# TIAA-CREF provides unit values via a cgi on their website. The cgi returns
# a csv file in the format
#		bogus_symbol1,price1,date1
#		bogus_symbol2,price2,date2
#       ..etc.
# where bogus_symbol takes on the following values for the various annuities:
#
# CREF Bond Market Account:	CREFbond	41081991
# CREF Equity Index Account:	CREFequi	41082540
# CREF Global Equities Account:	CREFglob	41081992
# CREF Growth Account:	CREFgrow	41082544
# CREF Inflation-Linked Bond Account:	CREFinfb	41088773
# CREF Money Market Account:	CREFmony	41081993
# CREF Social Choice Account:	CREFsoci	41081994
# CREF Stock Account:	CREFstok	41081995
# TIAA Real Estate Account:	TIAAreal	41091375
# TIAA-CREF Bond Fund (Retirement):	TIDRX	4530828
# TIAA-CREF Bond Index Fund (Retirement):	TBIRX	20739662
# TIAA-CREF Bond Plus Fund (Retirement):	TCBRX	4530816
# TIAA-CREF Emerging Markets Equity Fund (Retirement):	TEMSX	26176543
# TIAA-CREF Emerging Markets Equity Index Fund (Retirement):	TEQSX	26176547
# TIAA-CREF Equity Index Fund (Retirement):	TIQRX	4530786
# TIAA-CREF Global Natural Resources Fund (Retirement):	TNRRX	39444919
# TIAA-CREF Growth & Income Fund (Retirement):	TRGIX	312536
# TIAA-CREF High Yield Fund (Retirement):	TIHRX	4530821
# TIAA-CREF Inflation-Linked Bond Fund (Retirement):	TIKRX	4530829
# TIAA-CREF International Equity Fund (Retirement):	TRERX	302323
# TIAA-CREF International Equity Index Fund (Retirement):	TRIEX	300269
# TIAA-CREF Large-Cap Growth Fund (Retirement):	TILRX	4530785
# TIAA-CREF Large-Cap Growth Index Fund (Retirement):	TRIRX	299525
# TIAA-CREF Large-Cap Value Fund (Retirement):	TRLCX	301332
# TIAA-CREF Large-Cap Value Index Fund (Retirement):	TRCVX	304333
# TIAA-CREF Lifecycle 2010 Fund (Retirement):	TCLEX	302817
# TIAA-CREF Lifecycle 2015 Fund (Retirement):	TCLIX	302393
# TIAA-CREF Lifecycle 2020 Fund (Retirement):	TCLTX	307774
# TIAA-CREF Lifecycle 2025 Fund (Retirement):	TCLFX	313994
# TIAA-CREF Lifecycle 2030 Fund (Retirement):	TCLNX	307240
# TIAA-CREF Lifecycle 2035 Fund (Retirement):	TCLRX	309003
# TIAA-CREF Lifecycle 2040 Fund (Retirement):	TCLOX	300959
# TIAA-CREF Lifecycle 2045 Fund (Retirement):	TTFRX	9467597
# TIAA-CREF Lifecycle 2050 Fund (Retirement):	TLFRX	9467596
# TIAA-CREF Lifecycle 2055 Fund (Retirement):	TTRLX	34211330
# TIAA-CREF Lifecycle Index 2010 Fund (Retirement):	TLTRX	21066482
# TIAA-CREF Lifecycle Index 2015 Fund (Retirement):	TLGRX	21066496
# TIAA-CREF Lifecycle Index 2020 Fund (Retirement):	TLWRX	21066479
# TIAA-CREF Lifecycle Index 2025 Fund (Retirement):	TLQRX	21066485
# TIAA-CREF Lifecycle Index 2030 Fund (Retirement):	TLHRX	21066435
# TIAA-CREF Lifecycle Index 2035 Fund (Retirement):	TLYRX	21066475
# TIAA-CREF Lifecycle Index 2040 Fund (Retirement):	TLZRX	21066473
# TIAA-CREF Lifecycle Index 2045 Fund (Retirement):	TLMRX	21066488
# TIAA-CREF Lifecycle Index 2050 Fund (Retirement):	TLLRX	21066490
# TIAA-CREF Lifecycle Index 2055 Fund (Retirement):	TTIRX	34211328
# TIAA-CREF Lifecycle Index Retirement Income Fund (Retirement):	TRCIX	21066468
# TIAA-CREF Lifecycle Retirement Income Fund (Retirement):	TLIRX	9467594
# TIAA-CREF Lifestyle Aggressive Growth Fund (Retirement):	TSARX	40508431
# TIAA-CREF Lifestyle Conservative Fund (Retirement):	TSCTX	40508433
# TIAA-CREF Lifestyle Growth Fund (Retirement):	TSGRX	40508437
# TIAA-CREF Lifestyle Income Fund (Retirement):	TLSRX	40508427
# TIAA-CREF Lifestyle Moderate Fund (Retirement):	TSMTX	40508460
# TIAA-CREF Managed Allocation Fund (Retirement):	TITRX	4530825
# TIAA-CREF Mid-Cap Growth Fund (Retirement):	TRGMX	305499
# TIAA-CREF Mid-Cap Value Fund (Retirement):	TRVRX	315272
# TIAA-CREF Money Market Fund (Retirement):	TIEXX	4530771
# TIAA-CREF Real Estate Securities Fund (Retirement):	TRRSX	300081
# TIAA-CREF S&P 500 Index Fund (Retirement):	TRSPX	306105
# TIAA-CREF Short-Term Bond Fund (Retirement):	TISRX	4530818
# TIAA-CREF Small-Cap Blend Index Fund (Retirement):	TRBIX	314644
# TIAA-CREF Small-Cap Equity Fund (Retirement):	TRSEX	299968
# TIAA-CREF Social Choice Equity Fund (Retirement):	TRSCX	300078
# TIAA-CREF Bond Fund (Institutional):	TIBDX	307276
# TIAA-CREF Bond Index Fund (Institutional):	TBIIX	20739664
# TIAA-CREF Bond Plus Fund (Institutional):	TIBFX	4530820
# TIAA-CREF Emerging Markets Equity Fund (Institutional):	TEMLX	26176540
# TIAA-CREF Emerging Markets Equity Index Fund (Institutional):	TEQLX	26176544
# TIAA-CREF Enhanced International Equity Index Fund (Institutional):	TFIIX	9467603
# TIAA-CREF Enhanced Large-Cap Growth Index Fund (Institutional):	TLIIX	9467602
# TIAA-CREF Enhanced Large-Cap Value Index Fund (Institutional):	TEVIX	9467606
# TIAA-CREF Equity Index Fund (Institutional):	TIEIX	301718
# TIAA-CREF Global Natural Resources Fund (Institutional):	TNRIX	39444916
# TIAA-CREF Growth & Income Fund (Institutional):	TIGRX	314719
# TIAA-CREF High Yield Fund (Institutional):	TIHYX	4530798
# TIAA-CREF Inflation-Linked Bond Fund (Institutional):	TIILX	316693
# TIAA-CREF International Equity Fund (Institutional):	TIIEX	305980
# TIAA-CREF International Equity Index Fund (Institutional):	TCIEX	303673
# TIAA-CREF Large-Cap Growth Fund (Institutional):	TILGX	4530800
# TIAA-CREF Large-Cap Growth Index Fund (Institutional):	TILIX	297809
# TIAA-CREF Large-Cap Value Fund (Institutional):	TRLIX	300692
# TIAA-CREF Large-Cap Value Index Fund (Institutional):	TILVX	302308
# TIAA-CREF Lifecycle 2010 Fund (Institutional):	TCTIX	4912376
# TIAA-CREF Lifecycle 2015 Fund (Institutional):	TCNIX	4912355
# TIAA-CREF Lifecycle 2020 Fund (Institutional):	TCWIX	4912377
# TIAA-CREF Lifecycle 2025 Fund (Institutional):	TCYIX	4912384
# TIAA-CREF Lifecycle 2030 Fund (Institutional):	TCRIX	4912364
# TIAA-CREF Lifecycle 2035 Fund (Institutional):	TCIIX	4912375
# TIAA-CREF Lifecycle 2040 Fund (Institutional):	TCOIX	4912387
# TIAA-CREF Lifecycle 2045 Fund (Institutional):	TTFIX	9467607
# TIAA-CREF Lifecycle 2050 Fund (Institutional):	TFTIX	9467601
# TIAA-CREF Lifecycle 2055 Fund (Institutional):	TTRIX	34211329
# TIAA-CREF Lifecycle Index 2010 Fund (Institutional):	TLTIX	21066484
# TIAA-CREF Lifecycle Index 2015 Fund (Institutional):	TLFIX	21066498
# TIAA-CREF Lifecycle Index 2020 Fund (Institutional):	TLWIX	21066480
# TIAA-CREF Lifecycle Index 2025 Fund (Institutional):	TLQIX	21066486
# TIAA-CREF Lifecycle Index 2030 Fund (Institutional):	TLHIX	21066495
# TIAA-CREF Lifecycle Index 2035 Fund (Institutional):	TLYIX	21066477
# TIAA-CREF Lifecycle Index 2040 Fund (Institutional):	TLZIX	21066474
# TIAA-CREF Lifecycle Index 2045 Fund (Institutional):	TLXIX	21066478
# TIAA-CREF Lifecycle Index 2050 Fund (Institutional):	TLLIX	21066492
# TIAA-CREF Lifecycle Index 2055 Fund (Institutional):	TTIIX	34211326
# TIAA-CREF Lifecycle Index Retirement Income Fund (Institutional):	TRILX	21066463
# TIAA-CREF Lifecycle Retirement Income Fund (Institutional):	TLRIX	9467595
# TIAA-CREF Lifestyle Aggressive Growth Fund (Institutional):	TSAIX	40508428
# TIAA-CREF Lifestyle Conservative Fund (Institutional):	TCSIX	40508425
# TIAA-CREF Lifestyle Growth Fund (Institutional):	TSGGX	40508434
# TIAA-CREF Lifestyle Income Fund (Institutional):	TSITX	40508450
# TIAA-CREF Lifestyle Moderate Fund (Institutional):	TSIMX	40508443
# TIAA-CREF Managed Allocation Fund (Institutional):	TIMIX	4530787
# TIAA-CREF Mid-Cap Growth Fund (Institutional):	TRPWX	297210
# TIAA-CREF Mid-Cap Value Fund (Institutional):	TIMVX	316178
# TIAA-CREF Money Market Fund (Institutional):	TCIXX	313650
# TIAA-CREF Real Estate Securities Fund (Institutional):	TIREX	303475
# TIAA-CREF S&P 500 Index Fund (Institutional):	TISPX	306658
# TIAA-CREF Short-Term Bond Fund (Institutional):	TISIX	4530784
# TIAA-CREF Small-Cap Blend Index Fund (Institutional):	TISBX	309018
# TIAA-CREF Small-Cap Equity Fund (Institutional):	TISEX	301622
# TIAA-CREF Social Choice Equity Fund (Institutional):	TISCX	301897
# TIAA-CREF Tax-Exempt Bond Fund (Institutional):	TITIX	4530819
# TIAA-CREF Bond Fund (Retail):	TIORX	4530794
# TIAA-CREF Bond Index Fund (Retail):	TBILX	20739663
# TIAA-CREF Bond Plus Fund (Retail):	TCBPX	4530788
# TIAA-CREF Emerging Markets Equity Fund (Retail):	TEMRX	26176542
# TIAA-CREF Emerging Markets Equity Index Fund (Retail):	TEQKX	26176545
# TIAA-CREF Equity Index Fund (Retail):	TINRX	4530797
# TIAA-CREF Global Natural Resources Fund (Retail):	TNRLX	39444917
# TIAA-CREF Growth & Income Fund (Retail):	TIIRX	4530790
# TIAA-CREF High Yield Fund (Retail):	TIYRX	4530830
# TIAA-CREF Inflation-Linked Bond Fund (Retail):	TCILX	313727
# TIAA-CREF International Equity Fund (Retail):	TIERX	4530827
# TIAA-CREF Large-Cap Growth Fund (Retail):	TIRTX	4530791
# TIAA-CREF Large-Cap Value Fund (Retail):	TCLCX	302696
# TIAA-CREF Lifecycle Retirement Income Fund (Retail):	TLRRX	9467600
# TIAA-CREF Lifestyle Aggressive Growth Fund (Retail):	TSALX	40508429
# TIAA-CREF Lifestyle Conservative Fund (Retail):	TSCLX	40508432
# TIAA-CREF Lifestyle Growth Fund (Retail):	TSGLX	40508435
# TIAA-CREF Lifestyle Income Fund (Retail):	TSILX	40508438
# TIAA-CREF Lifestyle Moderate Fund (Retail):	TSMLX	40508453
# TIAA-CREF Managed Allocation Fund (Retail):	TIMRX	4530817
# TIAA-CREF Mid-Cap Growth Fund (Retail):	TCMGX	305208
# TIAA-CREF Mid-Cap Value Fund (Retail):	TCMVX	313995
# TIAA-CREF Money Market Fund (Retail):	TIRXX	4530775
# TIAA-CREF Real Estate Securities Fund (Retail):	TCREX	309567
# TIAA-CREF Short-Term Bond Fund (Retail):	TCTRX	4530822
# TIAA-CREF Small-Cap Equity Fund (Retail):	TCSEX	297477
# TIAA-CREF Social Choice Equity Fund (Retail):	TICRX	4530792
# TIAA-CREF Tax-Exempt Bond Fund (Retail):	TIXRX	4530793
# TIAA-CREF Bond Fund (Premier):	TIDPX	21066506
# TIAA-CREF Bond Index Fund (Premier):	TBIPX	21066534
# TIAA-CREF Bond Plus Fund (Premier):	TBPPX	21066533
# TIAA-CREF Emerging Markets Equity Fund (Premier):	TEMPX	26176541
# TIAA-CREF Emerging Markets Equity Index Fund (Premier):	TEQPX	26176546
# TIAA-CREF Equity Index Fund (Premier):	TCEPX	21066530
# TIAA-CREF Global Natural Resources Fund (Premier):	TNRPX	39444918
# TIAA-CREF Growth & Income Fund (Premier):	TRPGX	21066461
# TIAA-CREF High Yield Fund (Premier):	TIHPX	21066501
# TIAA-CREF Inflation-Linked Bond Fund (Premier):	TIKPX	21066500
# TIAA-CREF International Equity Fund (Premier):	TREPX	21066466
# TIAA-CREF International Equity Index Fund (Premier):	TRIPX	21066462
# TIAA-CREF Large-Cap Growth Fund (Premier):	TILPX	21066499
# TIAA-CREF Large-Cap Value Fund (Premier):	TRCPX	21066467
# TIAA-CREF Lifecycle 2010 Fund (Premier):	TCTPX	21066521
# TIAA-CREF Lifecycle 2015 Fund (Premier):	TCFPX	21066528
# TIAA-CREF Lifecycle 2020 Fund (Premier):	TCWPX	21066518
# TIAA-CREF Lifecycle 2025 Fund (Premier):	TCQPX	21066522
# TIAA-CREF Lifecycle 2030 Fund (Premier):	TCHPX	21066527
# TIAA-CREF Lifecycle 2035 Fund (Premier):	TCYPX	21066517
# TIAA-CREF Lifecycle 2040 Fund (Premier):	TCZPX	21066516
# TIAA-CREF Lifecycle 2045 Fund (Premier):	TTFPX	21066444
# TIAA-CREF Lifecycle 2050 Fund (Premier):	TCLPX	21066526
# TIAA-CREF Lifecycle 2055 Fund (Premier):	TTRPX	34211331
# TIAA-CREF Lifecycle Index 2010 Fund (Premier):	TLTPX	21066483
# TIAA-CREF Lifecycle Index 2015 Fund (Premier):	TLFPX	21066497
# TIAA-CREF Lifecycle Index 2020 Fund (Premier):	TLWPX	21066434
# TIAA-CREF Lifecycle Index 2025 Fund (Premier):	TLVPX	21066481
# TIAA-CREF Lifecycle Index 2030 Fund (Premier):	TLHPX	21066494
# TIAA-CREF Lifecycle Index 2035 Fund (Premier):	TLYPX	21066476
# TIAA-CREF Lifecycle Index 2040 Fund (Premier):	TLPRX	21066487
# TIAA-CREF Lifecycle Index 2045 Fund (Premier):	TLMPX	21066489
# TIAA-CREF Lifecycle Index 2050 Fund (Premier):	TLLPX	21066491
# TIAA-CREF Lifecycle Index 2055 Fund (Premier):	TTIPX	34211327
# TIAA-CREF Lifecycle Index Retirement Income Fund (Premier):	TLIPX	21066493
# TIAA-CREF Lifecycle Retirement Income Fund (Premier):	TPILX	21066470
# TIAA-CREF Lifestyle Aggressive Growth Fund (Premier):	TSAPX	40508430
# TIAA-CREF Lifestyle Conservative Fund (Premier):	TLSPX	40508426
# TIAA-CREF Lifestyle Growth Fund (Premier):	TSGPX	40508436
# TIAA-CREF Lifestyle Income Fund (Premier):	TSIPX	40508451
# TIAA-CREF Lifestyle Moderate Fund (Premier):	TSMPX	40508456
# TIAA-CREF Mid-Cap Growth Fund (Premier):	TRGPX	21066464
# TIAA-CREF Mid-Cap Value Fund (Premier):	TRVPX	21066455
# TIAA-CREF Money Market Fund (Premier):	TPPXX	21066469
# TIAA-CREF Real Estate Securities Fund (Premier):	TRRPX	21066459
# TIAA-CREF Short-Term Bond Fund (Premier):	TSTPX	21066445
# TIAA-CREF Small-Cap Equity Fund (Premier):	TSRPX	21066446
# TIAA-CREF Social Choice Equity Fund (Premier):	TRPSX	21066460

#
# This subroutine was written by Brent Neal <brentn@users.sourceforge.net>
# Modified to support new TIAA-CREF webpages by Kevin Foss <kfoss@maine.edu> and Brent Neal
# Modified to support new 2012 TIAA-CREF webpages by Carl LaCombe <calcisme@gmail.com>

#
# TODO:
#
# The TIAA-CREF cgi allows you to specify the exact dates for which to retrieve
# price data. That functionality could be worked into this subroutine.
# Currently, we only grab the most recent price data.
#

sub tiaacref
{
	my $quoter = shift;
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

	if (! %tiaacref_vals) {
		$tiaacref_vals{"CREFbond"} = "41081991";
		$tiaacref_vals{"CREFequi"} = "41082540";
		$tiaacref_vals{"CREFglob"} = "41081992";
		$tiaacref_vals{"CREFgrow"} = "41082544";
		$tiaacref_vals{"CREFinfb"} = "41088773";
		$tiaacref_vals{"CREFmony"} = "41081993";
		$tiaacref_vals{"CREFsoci"} = "41081994";
		$tiaacref_vals{"CREFstok"} = "41081995";
		$tiaacref_vals{"TIAAreal"} = "41091375";
		$tiaacref_vals{"TIDRX"} = "4530828";
		$tiaacref_vals{"TBIRX"} = "20739662";
		$tiaacref_vals{"TCBRX"} = "4530816";
		$tiaacref_vals{"TEMSX"} = "26176543";
		$tiaacref_vals{"TEQSX"} = "26176547";
		$tiaacref_vals{"TIQRX"} = "4530786";
		$tiaacref_vals{"TNRRX"} = "39444919";
		$tiaacref_vals{"TRGIX"} = "312536";
		$tiaacref_vals{"TIHRX"} = "4530821";
		$tiaacref_vals{"TIKRX"} = "4530829";
		$tiaacref_vals{"TRERX"} = "302323";
		$tiaacref_vals{"TRIEX"} = "300269";
		$tiaacref_vals{"TILRX"} = "4530785";
		$tiaacref_vals{"TRIRX"} = "299525";
		$tiaacref_vals{"TRLCX"} = "301332";
		$tiaacref_vals{"TRCVX"} = "304333";
		$tiaacref_vals{"TCLEX"} = "302817";
		$tiaacref_vals{"TCLIX"} = "302393";
		$tiaacref_vals{"TCLTX"} = "307774";
		$tiaacref_vals{"TCLFX"} = "313994";
		$tiaacref_vals{"TCLNX"} = "307240";
		$tiaacref_vals{"TCLRX"} = "309003";
		$tiaacref_vals{"TCLOX"} = "300959";
		$tiaacref_vals{"TTFRX"} = "9467597";
		$tiaacref_vals{"TLFRX"} = "9467596";
		$tiaacref_vals{"TTRLX"} = "34211330";
		$tiaacref_vals{"TLTRX"} = "21066482";
		$tiaacref_vals{"TLGRX"} = "21066496";
		$tiaacref_vals{"TLWRX"} = "21066479";
		$tiaacref_vals{"TLQRX"} = "21066485";
		$tiaacref_vals{"TLHRX"} = "21066435";
		$tiaacref_vals{"TLYRX"} = "21066475";
		$tiaacref_vals{"TLZRX"} = "21066473";
		$tiaacref_vals{"TLMRX"} = "21066488";
		$tiaacref_vals{"TLLRX"} = "21066490";
		$tiaacref_vals{"TTIRX"} = "34211328";
		$tiaacref_vals{"TRCIX"} = "21066468";
		$tiaacref_vals{"TLIRX"} = "9467594";
		$tiaacref_vals{"TSARX"} = "40508431";
		$tiaacref_vals{"TSCTX"} = "40508433";
		$tiaacref_vals{"TSGRX"} = "40508437";
		$tiaacref_vals{"TLSRX"} = "40508427";
		$tiaacref_vals{"TSMTX"} = "40508460";
		$tiaacref_vals{"TITRX"} = "4530825";
		$tiaacref_vals{"TRGMX"} = "305499";
		$tiaacref_vals{"TRVRX"} = "315272";
		$tiaacref_vals{"TIEXX"} = "4530771";
		$tiaacref_vals{"TRRSX"} = "300081";
		$tiaacref_vals{"TRSPX"} = "306105";
		$tiaacref_vals{"TISRX"} = "4530818";
		$tiaacref_vals{"TRBIX"} = "314644";
		$tiaacref_vals{"TRSEX"} = "299968";
		$tiaacref_vals{"TRSCX"} = "300078";
		$tiaacref_vals{"TIBDX"} = "307276";
		$tiaacref_vals{"TBIIX"} = "20739664";
		$tiaacref_vals{"TIBFX"} = "4530820";
		$tiaacref_vals{"TEMLX"} = "26176540";
		$tiaacref_vals{"TEQLX"} = "26176544";
		$tiaacref_vals{"TFIIX"} = "9467603";
		$tiaacref_vals{"TLIIX"} = "9467602";
		$tiaacref_vals{"TEVIX"} = "9467606";
		$tiaacref_vals{"TIEIX"} = "301718";
		$tiaacref_vals{"TNRIX"} = "39444916";
		$tiaacref_vals{"TIGRX"} = "314719";
		$tiaacref_vals{"TIHYX"} = "4530798";
		$tiaacref_vals{"TIILX"} = "316693";
		$tiaacref_vals{"TIIEX"} = "305980";
		$tiaacref_vals{"TCIEX"} = "303673";
		$tiaacref_vals{"TILGX"} = "4530800";
		$tiaacref_vals{"TILIX"} = "297809";
		$tiaacref_vals{"TRLIX"} = "300692";
		$tiaacref_vals{"TILVX"} = "302308";
		$tiaacref_vals{"TCTIX"} = "4912376";
		$tiaacref_vals{"TCNIX"} = "4912355";
		$tiaacref_vals{"TCWIX"} = "4912377";
		$tiaacref_vals{"TCYIX"} = "4912384";
		$tiaacref_vals{"TCRIX"} = "4912364";
		$tiaacref_vals{"TCIIX"} = "4912375";
		$tiaacref_vals{"TCOIX"} = "4912387";
		$tiaacref_vals{"TTFIX"} = "9467607";
		$tiaacref_vals{"TFTIX"} = "9467601";
		$tiaacref_vals{"TTRIX"} = "34211329";
		$tiaacref_vals{"TLTIX"} = "21066484";
		$tiaacref_vals{"TLFIX"} = "21066498";
		$tiaacref_vals{"TLWIX"} = "21066480";
		$tiaacref_vals{"TLQIX"} = "21066486";
		$tiaacref_vals{"TLHIX"} = "21066495";
		$tiaacref_vals{"TLYIX"} = "21066477";
		$tiaacref_vals{"TLZIX"} = "21066474";
		$tiaacref_vals{"TLXIX"} = "21066478";
		$tiaacref_vals{"TLLIX"} = "21066492";
		$tiaacref_vals{"TTIIX"} = "34211326";
		$tiaacref_vals{"TRILX"} = "21066463";
		$tiaacref_vals{"TLRIX"} = "9467595";
		$tiaacref_vals{"TSAIX"} = "40508428";
		$tiaacref_vals{"TCSIX"} = "40508425";
		$tiaacref_vals{"TSGGX"} = "40508434";
		$tiaacref_vals{"TSITX"} = "40508450";
		$tiaacref_vals{"TSIMX"} = "40508443";
		$tiaacref_vals{"TIMIX"} = "4530787";
		$tiaacref_vals{"TRPWX"} = "297210";
		$tiaacref_vals{"TIMVX"} = "316178";
		$tiaacref_vals{"TCIXX"} = "313650";
		$tiaacref_vals{"TIREX"} = "303475";
		$tiaacref_vals{"TISPX"} = "306658";
		$tiaacref_vals{"TISIX"} = "4530784";
		$tiaacref_vals{"TISBX"} = "309018";
		$tiaacref_vals{"TISEX"} = "301622";
		$tiaacref_vals{"TISCX"} = "301897";
		$tiaacref_vals{"TITIX"} = "4530819";
		$tiaacref_vals{"TIORX"} = "4530794";
		$tiaacref_vals{"TBILX"} = "20739663";
		$tiaacref_vals{"TCBPX"} = "4530788";
		$tiaacref_vals{"TEMRX"} = "26176542";
		$tiaacref_vals{"TEQKX"} = "26176545";
		$tiaacref_vals{"TINRX"} = "4530797";
		$tiaacref_vals{"TNRLX"} = "39444917";
		$tiaacref_vals{"TIIRX"} = "4530790";
		$tiaacref_vals{"TIYRX"} = "4530830";
		$tiaacref_vals{"TCILX"} = "313727";
		$tiaacref_vals{"TIERX"} = "4530827";
		$tiaacref_vals{"TIRTX"} = "4530791";
		$tiaacref_vals{"TCLCX"} = "302696";
		$tiaacref_vals{"TLRRX"} = "9467600";
		$tiaacref_vals{"TSALX"} = "40508429";
		$tiaacref_vals{"TSCLX"} = "40508432";
		$tiaacref_vals{"TSGLX"} = "40508435";
		$tiaacref_vals{"TSILX"} = "40508438";
		$tiaacref_vals{"TSMLX"} = "40508453";
		$tiaacref_vals{"TIMRX"} = "4530817";
		$tiaacref_vals{"TCMGX"} = "305208";
		$tiaacref_vals{"TCMVX"} = "313995";
		$tiaacref_vals{"TIRXX"} = "4530775";
		$tiaacref_vals{"TCREX"} = "309567";
		$tiaacref_vals{"TCTRX"} = "4530822";
		$tiaacref_vals{"TCSEX"} = "297477";
		$tiaacref_vals{"TICRX"} = "4530792";
		$tiaacref_vals{"TIXRX"} = "4530793";
		$tiaacref_vals{"TIDPX"} = "21066506";
		$tiaacref_vals{"TBIPX"} = "21066534";
		$tiaacref_vals{"TBPPX"} = "21066533";
		$tiaacref_vals{"TEMPX"} = "26176541";
		$tiaacref_vals{"TEQPX"} = "26176546";
		$tiaacref_vals{"TCEPX"} = "21066530";
		$tiaacref_vals{"TNRPX"} = "39444918";
		$tiaacref_vals{"TRPGX"} = "21066461";
		$tiaacref_vals{"TIHPX"} = "21066501";
		$tiaacref_vals{"TIKPX"} = "21066500";
		$tiaacref_vals{"TREPX"} = "21066466";
		$tiaacref_vals{"TRIPX"} = "21066462";
		$tiaacref_vals{"TILPX"} = "21066499";
		$tiaacref_vals{"TRCPX"} = "21066467";
		$tiaacref_vals{"TCTPX"} = "21066521";
		$tiaacref_vals{"TCFPX"} = "21066528";
		$tiaacref_vals{"TCWPX"} = "21066518";
		$tiaacref_vals{"TCQPX"} = "21066522";
		$tiaacref_vals{"TCHPX"} = "21066527";
		$tiaacref_vals{"TCYPX"} = "21066517";
		$tiaacref_vals{"TCZPX"} = "21066516";
		$tiaacref_vals{"TTFPX"} = "21066444";
		$tiaacref_vals{"TCLPX"} = "21066526";
		$tiaacref_vals{"TTRPX"} = "34211331";
		$tiaacref_vals{"TLTPX"} = "21066483";
		$tiaacref_vals{"TLFPX"} = "21066497";
		$tiaacref_vals{"TLWPX"} = "21066434";
		$tiaacref_vals{"TLVPX"} = "21066481";
		$tiaacref_vals{"TLHPX"} = "21066494";
		$tiaacref_vals{"TLYPX"} = "21066476";
		$tiaacref_vals{"TLPRX"} = "21066487";
		$tiaacref_vals{"TLMPX"} = "21066489";
		$tiaacref_vals{"TLLPX"} = "21066491";
		$tiaacref_vals{"TTIPX"} = "34211327";
		$tiaacref_vals{"TLIPX"} = "21066493";
		$tiaacref_vals{"TPILX"} = "21066470";
		$tiaacref_vals{"TSAPX"} = "40508430";
		$tiaacref_vals{"TLSPX"} = "40508426";
		$tiaacref_vals{"TSGPX"} = "40508436";
		$tiaacref_vals{"TSIPX"} = "40508451";
		$tiaacref_vals{"TSMPX"} = "40508456";
		$tiaacref_vals{"TRGPX"} = "21066464";
		$tiaacref_vals{"TRVPX"} = "21066455";
		$tiaacref_vals{"TPPXX"} = "21066469";
		$tiaacref_vals{"TRRPX"} = "21066459";
		$tiaacref_vals{"TSTPX"} = "21066445";
		$tiaacref_vals{"TSRPX"} = "21066446";
		$tiaacref_vals{"TRPSX"} = "21066460";
	}

#The location doesn't matter anymore.
#I'm leaving this data structure in place in case it changes again
#FBN 23/JAN/04

	if (! %tiaacref_locs) {
		$tiaacref_locs{"CREFbond"} = 1;
		$tiaacref_locs{"CREFequi"} = 1;
		$tiaacref_locs{"CREFglob"} = 1;
		$tiaacref_locs{"CREFgrow"} = 1;
		$tiaacref_locs{"CREFinfb"} = 1;
		$tiaacref_locs{"CREFmony"} = 1;
		$tiaacref_locs{"CREFsoci"} = 1;
		$tiaacref_locs{"CREFstok"} = 1;
		$tiaacref_locs{"TIAAreal"} = 1;
		$tiaacref_locs{"TIDRX"} = 1;
		$tiaacref_locs{"TBIRX"} = 1;
		$tiaacref_locs{"TCBRX"} = 1;
		$tiaacref_locs{"TEMSX"} = 1;
		$tiaacref_locs{"TEQSX"} = 1;
		$tiaacref_locs{"TIQRX"} = 1;
		$tiaacref_locs{"TNRRX"} = 1;
		$tiaacref_locs{"TRGIX"} = 1;
		$tiaacref_locs{"TIHRX"} = 1;
		$tiaacref_locs{"TIKRX"} = 1;
		$tiaacref_locs{"TRERX"} = 1;
		$tiaacref_locs{"TRIEX"} = 1;
		$tiaacref_locs{"TILRX"} = 1;
		$tiaacref_locs{"TRIRX"} = 1;
		$tiaacref_locs{"TRLCX"} = 1;
		$tiaacref_locs{"TRCVX"} = 1;
		$tiaacref_locs{"TCLEX"} = 1;
		$tiaacref_locs{"TCLIX"} = 1;
		$tiaacref_locs{"TCLTX"} = 1;
		$tiaacref_locs{"TCLFX"} = 1;
		$tiaacref_locs{"TCLNX"} = 1;
		$tiaacref_locs{"TCLRX"} = 1;
		$tiaacref_locs{"TCLOX"} = 1;
		$tiaacref_locs{"TTFRX"} = 1;
		$tiaacref_locs{"TLFRX"} = 1;
		$tiaacref_locs{"TTRLX"} = 1;
		$tiaacref_locs{"TLTRX"} = 1;
		$tiaacref_locs{"TLGRX"} = 1;
		$tiaacref_locs{"TLWRX"} = 1;
		$tiaacref_locs{"TLQRX"} = 1;
		$tiaacref_locs{"TLHRX"} = 1;
		$tiaacref_locs{"TLYRX"} = 1;
		$tiaacref_locs{"TLZRX"} = 1;
		$tiaacref_locs{"TLMRX"} = 1;
		$tiaacref_locs{"TLLRX"} = 1;
		$tiaacref_locs{"TTIRX"} = 1;
		$tiaacref_locs{"TRCIX"} = 1;
		$tiaacref_locs{"TLIRX"} = 1;
		$tiaacref_locs{"TSARX"} = 1;
		$tiaacref_locs{"TSCTX"} = 1;
		$tiaacref_locs{"TSGRX"} = 1;
		$tiaacref_locs{"TLSRX"} = 1;
		$tiaacref_locs{"TSMTX"} = 1;
		$tiaacref_locs{"TITRX"} = 1;
		$tiaacref_locs{"TRGMX"} = 1;
		$tiaacref_locs{"TRVRX"} = 1;
		$tiaacref_locs{"TIEXX"} = 1;
		$tiaacref_locs{"TRRSX"} = 1;
		$tiaacref_locs{"TRSPX"} = 1;
		$tiaacref_locs{"TISRX"} = 1;
		$tiaacref_locs{"TRBIX"} = 1;
		$tiaacref_locs{"TRSEX"} = 1;
		$tiaacref_locs{"TRSCX"} = 1;
		$tiaacref_locs{"TIBDX"} = 1;
		$tiaacref_locs{"TBIIX"} = 1;
		$tiaacref_locs{"TIBFX"} = 1;
		$tiaacref_locs{"TEMLX"} = 1;
		$tiaacref_locs{"TEQLX"} = 1;
		$tiaacref_locs{"TFIIX"} = 1;
		$tiaacref_locs{"TLIIX"} = 1;
		$tiaacref_locs{"TEVIX"} = 1;
		$tiaacref_locs{"TIEIX"} = 1;
		$tiaacref_locs{"TNRIX"} = 1;
		$tiaacref_locs{"TIGRX"} = 1;
		$tiaacref_locs{"TIHYX"} = 1;
		$tiaacref_locs{"TIILX"} = 1;
		$tiaacref_locs{"TIIEX"} = 1;
		$tiaacref_locs{"TCIEX"} = 1;
		$tiaacref_locs{"TILGX"} = 1;
		$tiaacref_locs{"TILIX"} = 1;
		$tiaacref_locs{"TRLIX"} = 1;
		$tiaacref_locs{"TILVX"} = 1;
		$tiaacref_locs{"TCTIX"} = 1;
		$tiaacref_locs{"TCNIX"} = 1;
		$tiaacref_locs{"TCWIX"} = 1;
		$tiaacref_locs{"TCYIX"} = 1;
		$tiaacref_locs{"TCRIX"} = 1;
		$tiaacref_locs{"TCIIX"} = 1;
		$tiaacref_locs{"TCOIX"} = 1;
		$tiaacref_locs{"TTFIX"} = 1;
		$tiaacref_locs{"TFTIX"} = 1;
		$tiaacref_locs{"TTRIX"} = 1;
		$tiaacref_locs{"TLTIX"} = 1;
		$tiaacref_locs{"TLFIX"} = 1;
		$tiaacref_locs{"TLWIX"} = 1;
		$tiaacref_locs{"TLQIX"} = 1;
		$tiaacref_locs{"TLHIX"} = 1;
		$tiaacref_locs{"TLYIX"} = 1;
		$tiaacref_locs{"TLZIX"} = 1;
		$tiaacref_locs{"TLXIX"} = 1;
		$tiaacref_locs{"TLLIX"} = 1;
		$tiaacref_locs{"TTIIX"} = 1;
		$tiaacref_locs{"TRILX"} = 1;
		$tiaacref_locs{"TLRIX"} = 1;
		$tiaacref_locs{"TSAIX"} = 1;
		$tiaacref_locs{"TCSIX"} = 1;
		$tiaacref_locs{"TSGGX"} = 1;
		$tiaacref_locs{"TSITX"} = 1;
		$tiaacref_locs{"TSIMX"} = 1;
		$tiaacref_locs{"TIMIX"} = 1;
		$tiaacref_locs{"TRPWX"} = 1;
		$tiaacref_locs{"TIMVX"} = 1;
		$tiaacref_locs{"TCIXX"} = 1;
		$tiaacref_locs{"TIREX"} = 1;
		$tiaacref_locs{"TISPX"} = 1;
		$tiaacref_locs{"TISIX"} = 1;
		$tiaacref_locs{"TISBX"} = 1;
		$tiaacref_locs{"TISEX"} = 1;
		$tiaacref_locs{"TISCX"} = 1;
		$tiaacref_locs{"TITIX"} = 1;
		$tiaacref_locs{"TIORX"} = 1;
		$tiaacref_locs{"TBILX"} = 1;
		$tiaacref_locs{"TCBPX"} = 1;
		$tiaacref_locs{"TEMRX"} = 1;
		$tiaacref_locs{"TEQKX"} = 1;
		$tiaacref_locs{"TINRX"} = 1;
		$tiaacref_locs{"TNRLX"} = 1;
		$tiaacref_locs{"TIIRX"} = 1;
		$tiaacref_locs{"TIYRX"} = 1;
		$tiaacref_locs{"TCILX"} = 1;
		$tiaacref_locs{"TIERX"} = 1;
		$tiaacref_locs{"TIRTX"} = 1;
		$tiaacref_locs{"TCLCX"} = 1;
		$tiaacref_locs{"TLRRX"} = 1;
		$tiaacref_locs{"TSALX"} = 1;
		$tiaacref_locs{"TSCLX"} = 1;
		$tiaacref_locs{"TSGLX"} = 1;
		$tiaacref_locs{"TSILX"} = 1;
		$tiaacref_locs{"TSMLX"} = 1;
		$tiaacref_locs{"TIMRX"} = 1;
		$tiaacref_locs{"TCMGX"} = 1;
		$tiaacref_locs{"TCMVX"} = 1;
		$tiaacref_locs{"TIRXX"} = 1;
		$tiaacref_locs{"TCREX"} = 1;
		$tiaacref_locs{"TCTRX"} = 1;
		$tiaacref_locs{"TCSEX"} = 1;
		$tiaacref_locs{"TICRX"} = 1;
		$tiaacref_locs{"TIXRX"} = 1;
		$tiaacref_locs{"TIDPX"} = 1;
		$tiaacref_locs{"TBIPX"} = 1;
		$tiaacref_locs{"TBPPX"} = 1;
		$tiaacref_locs{"TEMPX"} = 1;
		$tiaacref_locs{"TEQPX"} = 1;
		$tiaacref_locs{"TCEPX"} = 1;
		$tiaacref_locs{"TNRPX"} = 1;
		$tiaacref_locs{"TRPGX"} = 1;
		$tiaacref_locs{"TIHPX"} = 1;
		$tiaacref_locs{"TIKPX"} = 1;
		$tiaacref_locs{"TREPX"} = 1;
		$tiaacref_locs{"TRIPX"} = 1;
		$tiaacref_locs{"TILPX"} = 1;
		$tiaacref_locs{"TRCPX"} = 1;
		$tiaacref_locs{"TCTPX"} = 1;
		$tiaacref_locs{"TCFPX"} = 1;
		$tiaacref_locs{"TCWPX"} = 1;
		$tiaacref_locs{"TCQPX"} = 1;
		$tiaacref_locs{"TCHPX"} = 1;
		$tiaacref_locs{"TCYPX"} = 1;
		$tiaacref_locs{"TCZPX"} = 1;
		$tiaacref_locs{"TTFPX"} = 1;
		$tiaacref_locs{"TCLPX"} = 1;
		$tiaacref_locs{"TTRPX"} = 1;
		$tiaacref_locs{"TLTPX"} = 1;
		$tiaacref_locs{"TLFPX"} = 1;
		$tiaacref_locs{"TLWPX"} = 1;
		$tiaacref_locs{"TLVPX"} = 1;
		$tiaacref_locs{"TLHPX"} = 1;
		$tiaacref_locs{"TLYPX"} = 1;
		$tiaacref_locs{"TLPRX"} = 1;
		$tiaacref_locs{"TLMPX"} = 1;
		$tiaacref_locs{"TLLPX"} = 1;
		$tiaacref_locs{"TTIPX"} = 1;
		$tiaacref_locs{"TLIPX"} = 1;
		$tiaacref_locs{"TPILX"} = 1;
		$tiaacref_locs{"TSAPX"} = 1;
		$tiaacref_locs{"TLSPX"} = 1;
		$tiaacref_locs{"TSGPX"} = 1;
		$tiaacref_locs{"TSIPX"} = 1;
		$tiaacref_locs{"TSMPX"} = 1;
		$tiaacref_locs{"TRGPX"} = 1;
		$tiaacref_locs{"TRVPX"} = 1;
		$tiaacref_locs{"TPPXX"} = 1;
		$tiaacref_locs{"TRRPX"} = 1;
		$tiaacref_locs{"TSTPX"} = 1;
		$tiaacref_locs{"TSRPX"} = 1;
		$tiaacref_locs{"TRPSX"} = 1;
	}
	my(@funds) = @_;
	return unless @funds;
	my(@line); #holds the return from parse_csv
	my(%info);
	my(%check); #holds success value if data returned
	my($ua,$urlc,$urlt); #useragent and target urls
	my($cntc,$cntt); #counters for each of the two url containers
	my($reply,$qdata); #the reply from TIAA-CREF's cgi and a buffer for the data

	$urlc = $CREF_URL;
	$urlt = $TIAA_URL;

#The new TIAA-CREF website asks for start and end dates. To guarantee data,
#ask for 7 days of quotes, and only take the first (most recent) one.
	my(@starttime, $startdate);
	@starttime = localtime(time-7*86400);
	$starttime[5] += 1900;
	$starttime[4] += 1;
	$startdate = $starttime[5] . "-" . $starttime[4] . "-" . $starttime[3];
	my(@endtime, $enddate);
	@endtime = localtime(time);
	$endtime[5] += 1900;
	$endtime[4] += 1;
	$enddate = $endtime[5] . "-" . $endtime[4] . "-" . $endtime[3];

	$urlc .= "&NavStart=" . $startdate . "&NavEnd=" . $enddate;

#Initialize counters for the two types of URL. If either counter is zero, then
# that URL will not be retrieved. This is less technically clever than testing
#the URL string itself with m/yes/, but its faster.
	$cntc = 0;
	$cntt = 0;
	foreach my $fund (@funds) {
		if ($tiaacref_ids{$fund}) {
			if ($tiaacref_locs{$fund} == 1) {
				$cntc++;
				$urlc .= "&WSODIssues=" . $tiaacref_vals{$fund};
			} else {
				$urlt .= $fund . "=yes&";
				$cntt++;
			}
			$check{$fund} = 0;
		} else {
			$info{$fund,"success"} = 0;
			$info{$fund,"errormsg"} = "Bad symbol";
		}
	}
	$urlc .= "&viewtype=CSV";
	$urlt .= "selected=1";

	$qdata ="";

	$ua = $quoter->user_agent;
	if ($cntc) {
		$reply = $ua->request(GET $urlc);
		if ($reply ->is_success) {
			$qdata .= $reply->content;
		}
	}
	if ($cntt) {
		$reply = $ua->request(GET $urlt);
		if ($reply ->is_success) {
			$qdata .= $reply->content;
		}
	}

	if (length($qdata)) {
	    $qdata = Encode::decode('utf16le', $qdata);
		foreach (split(/\012/,$qdata) ){
			next unless m/.+,.+/;
			s/[\r\n]+//g;
			s/^ +//g;
			s/ +$//g;
#			@line = split(/,/,$_);
			@line = $quoter->parse_csv($_);
			if($line[0] eq "CREF Bond Market Account"){$line[0] = "CREFbond";}
			if($line[0] eq "CREF Equity Index Account"){$line[0] = "CREFequi";}
			if($line[0] eq "CREF Global Equities Account"){$line[0] = "CREFglob";}
			if($line[0] eq "CREF Growth Account"){$line[0] = "CREFgrow";}
			if($line[0] eq "CREF Inflation-Linked Bond Account"){$line[0] = "CREFinfb";}
			if($line[0] eq "CREF Money Market Account"){$line[0] = "CREFmony";}
			if($line[0] eq "CREF Social Choice Account"){$line[0] = "CREFsoci";}
			if($line[0] eq "CREF Stock Account"){$line[0] = "CREFstok";}
			if($line[0] eq "TIAA Real Estate Account"){$line[0] = "TIAAreal";}
			if($check{$line[0]} == 1){next} #calcisme: this prevents getting more than the first of the quotes
			if (exists $check{$line[0]}) { #did we ask for this data?
				$info{$line[0],"symbol"} = $line[0]; #in case the caller needs this in the hash
				$info{$line[0],"exchange"} = "TIAA-CREF";
				$info{$line[0],"name"} = $tiaacref_ids{$line[0]};
				$quoter->store_date(\%info, $line[0], {usdate => $line[2]});
				$info{$line[0],"nav"} = $line[1];
				$info{$line[0],"price"} = $info{$line[0],"nav"};
				$info{$line[0],"success"} = 1; #this contains good data,
												#beyond a reasonable doubt
				$info{$line[0],"currency"} = "USD";
				$info{$line[0],"method"} = "tiaacref";
				$info{$line[0],"exchange"} = "TIAA-CREF";
				$check{$line[0]} = 1;
			} else {
				$info{$line[0],"success"} = 0;
				$info{$line[0],"errormsg"} = "Bad data returned";
			}
		}
	} else {
		foreach $_ (@funds) {
			$info{$_,"success"} = 0;
			$info{$_,"errormsg"} = "HTTP error";
		} # foreach
	} #if $length(qdata) else


	#now check to make sure a value was returned for every symbol asked for
	foreach my $k (keys %check) {
		if ($check{$k} == 0) {
			$info{$k,"success"} = 0;
			$info{$k,"errormsg"} = "No data returned";
		}
	}

	return %info if wantarray;
	return \%info;
}

1;

=head1 NAME

Finance::Quote::Tiaacref	- Obtain quote from TIAA-CREF.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %stockinfo = $q->fetch("tiaacref","TIAAreal");

=head1 DESCRIPTION

This module obtains information about TIAA-CREF managed funds.

The following symbols can be used:

    CREF Bond Market Account:	CREFbond
    CREF Equity Index Account:	CREFequi
    CREF Global Equities Account:	CREFglob
    CREF Growth Account:	CREFgrow
    CREF Inflation-Linked Bond Account:	CREFinfb
    CREF Money Market Account:	CREFmony
    CREF Social Choice Account:	CREFsoci
    CREF Stock Account:	CREFstok
    TIAA Real Estate Account:	TIAAreal
    TIAA-CREF Bond Fund (Retirement):	TIDRX
    TIAA-CREF Bond Index Fund (Retirement):	TBIRX
    TIAA-CREF Bond Plus Fund (Retirement):	TCBRX
    TIAA-CREF Emerging Markets Equity Fund (Retirement):	TEMSX
    TIAA-CREF Emerging Markets Equity Index Fund (Retirement):	TEQSX
    TIAA-CREF Equity Index Fund (Retirement):	TIQRX
    TIAA-CREF Global Natural Resources Fund (Retirement):	TNRRX
    TIAA-CREF Growth & Income Fund (Retirement):	TRGIX
    TIAA-CREF High Yield Fund (Retirement):	TIHRX
    TIAA-CREF Inflation-Linked Bond Fund (Retirement):	TIKRX
    TIAA-CREF International Equity Fund (Retirement):	TRERX
    TIAA-CREF International Equity Index Fund (Retirement):	TRIEX
    TIAA-CREF Large-Cap Growth Fund (Retirement):	TILRX
    TIAA-CREF Large-Cap Growth Index Fund (Retirement):	TRIRX
    TIAA-CREF Large-Cap Value Fund (Retirement):	TRLCX
    TIAA-CREF Large-Cap Value Index Fund (Retirement):	TRCVX
    TIAA-CREF Lifecycle 2010 Fund (Retirement):	TCLEX
    TIAA-CREF Lifecycle 2015 Fund (Retirement):	TCLIX
    TIAA-CREF Lifecycle 2020 Fund (Retirement):	TCLTX
    TIAA-CREF Lifecycle 2025 Fund (Retirement):	TCLFX
    TIAA-CREF Lifecycle 2030 Fund (Retirement):	TCLNX
    TIAA-CREF Lifecycle 2035 Fund (Retirement):	TCLRX
    TIAA-CREF Lifecycle 2040 Fund (Retirement):	TCLOX
    TIAA-CREF Lifecycle 2045 Fund (Retirement):	TTFRX
    TIAA-CREF Lifecycle 2050 Fund (Retirement):	TLFRX
    TIAA-CREF Lifecycle 2055 Fund (Retirement):	TTRLX
    TIAA-CREF Lifecycle Index 2010 Fund (Retirement):	TLTRX
    TIAA-CREF Lifecycle Index 2015 Fund (Retirement):	TLGRX
    TIAA-CREF Lifecycle Index 2020 Fund (Retirement):	TLWRX
    TIAA-CREF Lifecycle Index 2025 Fund (Retirement):	TLQRX
    TIAA-CREF Lifecycle Index 2030 Fund (Retirement):	TLHRX
    TIAA-CREF Lifecycle Index 2035 Fund (Retirement):	TLYRX
    TIAA-CREF Lifecycle Index 2040 Fund (Retirement):	TLZRX
    TIAA-CREF Lifecycle Index 2045 Fund (Retirement):	TLMRX
    TIAA-CREF Lifecycle Index 2050 Fund (Retirement):	TLLRX
    TIAA-CREF Lifecycle Index 2055 Fund (Retirement):	TTIRX
    TIAA-CREF Lifecycle Index Retirement Income Fund (Retirement):	TRCIX
    TIAA-CREF Lifecycle Retirement Income Fund (Retirement):	TLIRX
    TIAA-CREF Lifestyle Aggressive Growth Fund (Retirement):	TSARX
    TIAA-CREF Lifestyle Conservative Fund (Retirement):	TSCTX
    TIAA-CREF Lifestyle Growth Fund (Retirement):	TSGRX
    TIAA-CREF Lifestyle Income Fund (Retirement):	TLSRX
    TIAA-CREF Lifestyle Moderate Fund (Retirement):	TSMTX
    TIAA-CREF Managed Allocation Fund (Retirement):	TITRX
    TIAA-CREF Mid-Cap Growth Fund (Retirement):	TRGMX
    TIAA-CREF Mid-Cap Value Fund (Retirement):	TRVRX
    TIAA-CREF Money Market Fund (Retirement):	TIEXX
    TIAA-CREF Real Estate Securities Fund (Retirement):	TRRSX
    TIAA-CREF S&P 500 Index Fund (Retirement):	TRSPX
    TIAA-CREF Short-Term Bond Fund (Retirement):	TISRX
    TIAA-CREF Small-Cap Blend Index Fund (Retirement):	TRBIX
    TIAA-CREF Small-Cap Equity Fund (Retirement):	TRSEX
    TIAA-CREF Social Choice Equity Fund (Retirement):	TRSCX
    TIAA-CREF Bond Fund (Institutional):	TIBDX
    TIAA-CREF Bond Index Fund (Institutional):	TBIIX
    TIAA-CREF Bond Plus Fund (Institutional):	TIBFX
    TIAA-CREF Emerging Markets Equity Fund (Institutional):	TEMLX
    TIAA-CREF Emerging Markets Equity Index Fund (Institutional):	TEQLX
    TIAA-CREF Enhanced International Equity Index Fund (Institutional):	TFIIX
    TIAA-CREF Enhanced Large-Cap Growth Index Fund (Institutional):	TLIIX
    TIAA-CREF Enhanced Large-Cap Value Index Fund (Institutional):	TEVIX
    TIAA-CREF Equity Index Fund (Institutional):	TIEIX
    TIAA-CREF Global Natural Resources Fund (Institutional):	TNRIX
    TIAA-CREF Growth & Income Fund (Institutional):	TIGRX
    TIAA-CREF High Yield Fund (Institutional):	TIHYX
    TIAA-CREF Inflation-Linked Bond Fund (Institutional):	TIILX
    TIAA-CREF International Equity Fund (Institutional):	TIIEX
    TIAA-CREF International Equity Index Fund (Institutional):	TCIEX
    TIAA-CREF Large-Cap Growth Fund (Institutional):	TILGX
    TIAA-CREF Large-Cap Growth Index Fund (Institutional):	TILIX
    TIAA-CREF Large-Cap Value Fund (Institutional):	TRLIX
    TIAA-CREF Large-Cap Value Index Fund (Institutional):	TILVX
    TIAA-CREF Lifecycle 2010 Fund (Institutional):	TCTIX
    TIAA-CREF Lifecycle 2015 Fund (Institutional):	TCNIX
    TIAA-CREF Lifecycle 2020 Fund (Institutional):	TCWIX
    TIAA-CREF Lifecycle 2025 Fund (Institutional):	TCYIX
    TIAA-CREF Lifecycle 2030 Fund (Institutional):	TCRIX
    TIAA-CREF Lifecycle 2035 Fund (Institutional):	TCIIX
    TIAA-CREF Lifecycle 2040 Fund (Institutional):	TCOIX
    TIAA-CREF Lifecycle 2045 Fund (Institutional):	TTFIX
    TIAA-CREF Lifecycle 2050 Fund (Institutional):	TFTIX
    TIAA-CREF Lifecycle 2055 Fund (Institutional):	TTRIX
    TIAA-CREF Lifecycle Index 2010 Fund (Institutional):	TLTIX
    TIAA-CREF Lifecycle Index 2015 Fund (Institutional):	TLFIX
    TIAA-CREF Lifecycle Index 2020 Fund (Institutional):	TLWIX
    TIAA-CREF Lifecycle Index 2025 Fund (Institutional):	TLQIX
    TIAA-CREF Lifecycle Index 2030 Fund (Institutional):	TLHIX
    TIAA-CREF Lifecycle Index 2035 Fund (Institutional):	TLYIX
    TIAA-CREF Lifecycle Index 2040 Fund (Institutional):	TLZIX
    TIAA-CREF Lifecycle Index 2045 Fund (Institutional):	TLXIX
    TIAA-CREF Lifecycle Index 2050 Fund (Institutional):	TLLIX
    TIAA-CREF Lifecycle Index 2055 Fund (Institutional):	TTIIX
    TIAA-CREF Lifecycle Index Retirement Income Fund (Institutional):	TRILX
    TIAA-CREF Lifecycle Retirement Income Fund (Institutional):	TLRIX
    TIAA-CREF Lifestyle Aggressive Growth Fund (Institutional):	TSAIX
    TIAA-CREF Lifestyle Conservative Fund (Institutional):	TCSIX
    TIAA-CREF Lifestyle Growth Fund (Institutional):	TSGGX
    TIAA-CREF Lifestyle Income Fund (Institutional):	TSITX
    TIAA-CREF Lifestyle Moderate Fund (Institutional):	TSIMX
    TIAA-CREF Managed Allocation Fund (Institutional):	TIMIX
    TIAA-CREF Mid-Cap Growth Fund (Institutional):	TRPWX
    TIAA-CREF Mid-Cap Value Fund (Institutional):	TIMVX
    TIAA-CREF Money Market Fund (Institutional):	TCIXX
    TIAA-CREF Real Estate Securities Fund (Institutional):	TIREX
    TIAA-CREF S&P 500 Index Fund (Institutional):	TISPX
    TIAA-CREF Short-Term Bond Fund (Institutional):	TISIX
    TIAA-CREF Small-Cap Blend Index Fund (Institutional):	TISBX
    TIAA-CREF Small-Cap Equity Fund (Institutional):	TISEX
    TIAA-CREF Social Choice Equity Fund (Institutional):	TISCX
    TIAA-CREF Tax-Exempt Bond Fund (Institutional):	TITIX
    TIAA-CREF Bond Fund (Retail):	TIORX
    TIAA-CREF Bond Index Fund (Retail):	TBILX
    TIAA-CREF Bond Plus Fund (Retail):	TCBPX
    TIAA-CREF Emerging Markets Equity Fund (Retail):	TEMRX
    TIAA-CREF Emerging Markets Equity Index Fund (Retail):	TEQKX
    TIAA-CREF Equity Index Fund (Retail):	TINRX
    TIAA-CREF Global Natural Resources Fund (Retail):	TNRLX
    TIAA-CREF Growth & Income Fund (Retail):	TIIRX
    TIAA-CREF High Yield Fund (Retail):	TIYRX
    TIAA-CREF Inflation-Linked Bond Fund (Retail):	TCILX
    TIAA-CREF International Equity Fund (Retail):	TIERX
    TIAA-CREF Large-Cap Growth Fund (Retail):	TIRTX
    TIAA-CREF Large-Cap Value Fund (Retail):	TCLCX
    TIAA-CREF Lifecycle Retirement Income Fund (Retail):	TLRRX
    TIAA-CREF Lifestyle Aggressive Growth Fund (Retail):	TSALX
    TIAA-CREF Lifestyle Conservative Fund (Retail):	TSCLX
    TIAA-CREF Lifestyle Growth Fund (Retail):	TSGLX
    TIAA-CREF Lifestyle Income Fund (Retail):	TSILX
    TIAA-CREF Lifestyle Moderate Fund (Retail):	TSMLX
    TIAA-CREF Managed Allocation Fund (Retail):	TIMRX
    TIAA-CREF Mid-Cap Growth Fund (Retail):	TCMGX
    TIAA-CREF Mid-Cap Value Fund (Retail):	TCMVX
    TIAA-CREF Money Market Fund (Retail):	TIRXX
    TIAA-CREF Real Estate Securities Fund (Retail):	TCREX
    TIAA-CREF Short-Term Bond Fund (Retail):	TCTRX
    TIAA-CREF Small-Cap Equity Fund (Retail):	TCSEX
    TIAA-CREF Social Choice Equity Fund (Retail):	TICRX
    TIAA-CREF Tax-Exempt Bond Fund (Retail):	TIXRX
    TIAA-CREF Bond Fund (Premier):	TIDPX
    TIAA-CREF Bond Index Fund (Premier):	TBIPX
    TIAA-CREF Bond Plus Fund (Premier):	TBPPX
    TIAA-CREF Emerging Markets Equity Fund (Premier):	TEMPX
    TIAA-CREF Emerging Markets Equity Index Fund (Premier):	TEQPX
    TIAA-CREF Equity Index Fund (Premier):	TCEPX
    TIAA-CREF Global Natural Resources Fund (Premier):	TNRPX
    TIAA-CREF Growth & Income Fund (Premier):	TRPGX
    TIAA-CREF High Yield Fund (Premier):	TIHPX
    TIAA-CREF Inflation-Linked Bond Fund (Premier):	TIKPX
    TIAA-CREF International Equity Fund (Premier):	TREPX
    TIAA-CREF International Equity Index Fund (Premier):	TRIPX
    TIAA-CREF Large-Cap Growth Fund (Premier):	TILPX
    TIAA-CREF Large-Cap Value Fund (Premier):	TRCPX
    TIAA-CREF Lifecycle 2010 Fund (Premier):	TCTPX
    TIAA-CREF Lifecycle 2015 Fund (Premier):	TCFPX
    TIAA-CREF Lifecycle 2020 Fund (Premier):	TCWPX
    TIAA-CREF Lifecycle 2025 Fund (Premier):	TCQPX
    TIAA-CREF Lifecycle 2030 Fund (Premier):	TCHPX
    TIAA-CREF Lifecycle 2035 Fund (Premier):	TCYPX
    TIAA-CREF Lifecycle 2040 Fund (Premier):	TCZPX
    TIAA-CREF Lifecycle 2045 Fund (Premier):	TTFPX
    TIAA-CREF Lifecycle 2050 Fund (Premier):	TCLPX
    TIAA-CREF Lifecycle 2055 Fund (Premier):	TTRPX
    TIAA-CREF Lifecycle Index 2010 Fund (Premier):	TLTPX
    TIAA-CREF Lifecycle Index 2015 Fund (Premier):	TLFPX
    TIAA-CREF Lifecycle Index 2020 Fund (Premier):	TLWPX
    TIAA-CREF Lifecycle Index 2025 Fund (Premier):	TLVPX
    TIAA-CREF Lifecycle Index 2030 Fund (Premier):	TLHPX
    TIAA-CREF Lifecycle Index 2035 Fund (Premier):	TLYPX
    TIAA-CREF Lifecycle Index 2040 Fund (Premier):	TLPRX
    TIAA-CREF Lifecycle Index 2045 Fund (Premier):	TLMPX
    TIAA-CREF Lifecycle Index 2050 Fund (Premier):	TLLPX
    TIAA-CREF Lifecycle Index 2055 Fund (Premier):	TTIPX
    TIAA-CREF Lifecycle Index Retirement Income Fund (Premier):	TLIPX
    TIAA-CREF Lifecycle Retirement Income Fund (Premier):	TPILX
    TIAA-CREF Lifestyle Aggressive Growth Fund (Premier):	TSAPX
    TIAA-CREF Lifestyle Conservative Fund (Premier):	TLSPX
    TIAA-CREF Lifestyle Growth Fund (Premier):	TSGPX
    TIAA-CREF Lifestyle Income Fund (Premier):	TSIPX
    TIAA-CREF Lifestyle Moderate Fund (Premier):	TSMPX
    TIAA-CREF Mid-Cap Growth Fund (Premier):	TRGPX
    TIAA-CREF Mid-Cap Value Fund (Premier):	TRVPX
    TIAA-CREF Money Market Fund (Premier):	TPPXX
    TIAA-CREF Real Estate Securities Fund (Premier):	TRRPX
    TIAA-CREF Short-Term Bond Fund (Premier):	TSTPX
    TIAA-CREF Small-Cap Equity Fund (Premier):	TSRPX
    TIAA-CREF Social Choice Equity Fund (Premier):	TRPSX

This module is loaded by default on a Finance::Quote object.  It's
also possible to load it explicitly by passing "Tiaacref" in to the
argument argument list of Finance::Quote->new().

Information returned by this module is governed by TIAA-CREF's terms
and conditions.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::Tiaacref:
symbol, exchange, name, date, nav, price.

=head1 SEE ALSO

TIAA-CREF, http://www.tiaa-cref.org/

=cut
