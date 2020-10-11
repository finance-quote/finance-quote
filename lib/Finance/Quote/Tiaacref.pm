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
#    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
#    02110-1301, USA
#
#
# This code derived from Padzensky's work on package Finance::YahooQuote,
# but extends its capabilites to encompas a greater number of data sources.
#
# This code was developed as part of GnuCash <http://www.gnucash.org/>

package Finance::Quote::Tiaacref;
require 5.005;

use strict;

use Encode qw/decode/;
use Time::Piece;
use Time::Seconds;
use Try::Tiny;

# VERSION

# URLs of where to obtain information.
my $TIAA_MAIN_URL = 'https://www.tiaa.org/public/investment-performance';
my $TIAA_DATA_URL = 'https://www.tiaa.markitondemand.com/Research/Public/Export/Details';

sub methods { return (tiaacref=>\&tiaacref); }

sub labels { return (tiaacref => [qw/
    method
    symbol
    exchange
    name
    date
    isodate
    nav
    price
    currency
/]); }

# =======================================================================
# TIAA-CREF Annuities are not listed on any exchange, unlike their mutual funds
# TIAA-CREF provides unit values via a cgi on their website. The cgi returns
# a csv file in the format
#   description,price1,date1
#   description,price2,date2
#       ..etc.

# As of 11-Oct-2020, the following securities are found in their lookup
# service. Data for some of these are available elsewhere and some are not:

# QCBMIX  QCBMPX  QCBMRX  QCEQIX  QCEQPX  QCEQRX  QCGLIX  QCGLPX  QCGLRX  
# QCGRIX  QCGRPX  QCGRRX  QCILIX  QCILPX  QCILRX  QCMMIX  QCMMPX  QCMMRX  
# QCSCIX  QCSCPX  QCSCRX  QCSTIX  QCSTPX  QCSTRX  QREARX  TAISX   TAIWX   
# TBBWX   TBIAX   TBIIX   TBILX   TBIPX   TBIRX   TBIWX   TBPPX   TCBHX   
# TCBPX   TCBRX   TCBWX   TCCHX   TCEPX   TCFPX   TCHHX   TCHPX   TCIEX   
# TCIHX   TCIIX   TCILX   TCIWX   TCIXX   TCLCX   TCLEX   TCLFX   TCLHX   
# TCLIX   TCLNX   TCLOX   TCLPX   TCLRX   TCLTX   TCMGX   TCMHX   TCMVX   
# TCNHX   TCNIX   TCOIX   TCQHX   TCQPX   TCREX   TCRIX   TCSEX   TCSIX   
# TCTHX   TCTIX   TCTPX   TCTRX   TCTWX   TCWHX   TCWIX   TCWPX   TCYHX   
# TCYIX   TCYPX   TCZHX   TCZPX   TECGX   TECWX   TEDHX   TEDLX   TEDNX   
# TEDPX   TEDTX   TEDVX   TEIEX   TEIHX   TEIWX   TELCX   TELWX   TEMHX   
# TEMLX   TEMPX   TEMRX   TEMSX   TEMVX   TENWX   TEQHX   TEQKX   TEQLX   
# TEQPX   TEQSX   TEQWX   TESHX   TEVIX   TEWCX   TFIHX   TFIIX   TFIPX   
# TFIRX   TFITX   TFTHX   TFTIX   TGIHX   TGIWX   TGRKX   TGRLX   TGRMX   
# TGRNX   TGROX   THCVX   THCWX   TIBDX   TIBEX   TIBFX   TIBHX   TIBLX   
# TIBNX   TIBUX   TIBVX   TIBWX   TICHX   TICRX   TIDPX   TIDRX   TIEHX   
# TIEIX   TIERX   TIEWX   TIEXX   TIGRX   TIHHX   TIHPX   TIHRX   TIHWX   
# TIHYX   TIIEX   TIIHX   TIILX   TIIRX   TIISX   TIIWX   TIKPX   TIKRX   
# TILGX   TILHX   TILIX   TILPX   TILRX   TILVX   TILWX   TIMIX   TIMRX   
# TIMVX   TINRX   TIOHX   TIOIX   TIOPX   TIORX   TIOSX   TIOTX   TIOVX   
# TIQRX   TIREX   TIRHX   TIRTX   TIRXX   TISAX   TISBX   TISCX   TISEX   
# TISIX   TISPX   TISRX   TISWX   TITIX   TITRX   TIXHX   TIXRX   TIYRX   
# TLFAX   TLFIX   TLFPX   TLFRX   TLGRX   TLHHX   TLHIX   TLHPX   TLHRX   
# TLIHX   TLIIX   TLIPX   TLIRX   TLISX   TLLHX   TLLIX   TLLPX   TLLRX   
# TLMHX   TLMPX   TLMRX   TLPRX   TLQHX   TLQIX   TLQRX   TLRHX   TLRIX   
# TLRRX   TLSHX   TLSPX   TLSRX   TLTHX   TLTIX   TLTPX   TLTRX   TLVPX   
# TLWCX   TLWHX   TLWIX   TLWPX   TLWRX   TLXHX   TLXIX   TLXNX   TLXPX   
# TLXRX   TLYHX   TLYIX   TLYPX   TLYRX   TLZHX   TLZIX   TLZRX   TMHXX   
# TNSHX   TNWCX   TPILX   TPISX   TPPXX   TPSHX   TPWCX   TRBIX   TRCIX   
# TRCPX   TRCVX   TREPX   TRERX   TRGIX   TRGMX   TRGPX   TRHBX   TRIEX   
# TRIHX   TRILX   TRIPX   TRIRX   TRIWX   TRLCX   TRLHX   TRLIX   TRLWX   
# TRPGX   TRPSX   TRPWX   TRRPX   TRRSX   TRSCX   TRSEX   TRSHX   TRSPX   
# TRVHX   TRVPX   TRVRX   TSAHX   TSAIX   TSALX   TSAPX   TSARX   TSBBX   
# TSBHX   TSBIX   TSBPX   TSBRX   TSCHX   TSCLX   TSCTX   TSCWX   TSDBX   
# TSDDX   TSDFX   TSDHX   TSDJX   TSFHX   TSFPX   TSFRX   TSFTX   TSGGX   
# TSGHX   TSGLX   TSGPX   TSGRX   TSIHX   TSILX   TSIMX   TSIPX   TSITX   
# TSMEX   TSMHX   TSMLX   TSMMX   TSMNX   TSMOX   TSMPX   TSMTX   TSMUX   
# TSMWX   TSOEX   TSOHX   TSONX   TSOPX   TSORX   TSRPX   TSTPX   TTBHX   
# TTBWX   TTFHX   TTFIX   TTFPX   TTFRX   TTIHX   TTIIX   TTIPX   TTIRX   
# TTISX   TTRHX   TTRIX   TTRLX   TTRPX   TVIHX   TVIIX   TVIPX   TVITX   
# W111#   W113#   W114#   W115#   W116#   W117#   W118#   W119#   W120#   
# W121#   W122#   W123#   W128#   W130#   W131#   W132#   W133#   W134#   
# W135#   W136#   W137#   W138#   W139#   W140#   W141#   W142#   W143#   
# W144#   W145#   W146#   W147#   W148#   W149#   W150#   W151#   W152#   
# W153#   W154#   W155#   W156#   W157#   W158#   W159#   W160#   W161#   
# W162#   W163#   W164#   W165#   W166#   W167#   W168#   W169#   W170#   
# W171#   W172#   W173#   W174#   W175#   W176#   W177#   W178#   W179#   
# W180#   W211#   W213#   W214#   W215#   W216#   W217#   W218#   W219#   
# W220#   W221#   W222#   W223#   W228#   W230#   W231#   W232#   W233#   
# W234#   W235#   W236#   W237#   W238#   W239#   W240#   W241#   W242#   
# W243#   W244#   W245#   W246#   W247#   W248#   W249#   W250#   W251#   
# W252#   W253#   W254#   W255#   W256#   W257#   W258#   W259#   W260#   
# W261#   W262#   W263#   W264#   W265#   W266#   W267#   W268#   W269#   
# W270#   W271#   W272#   W273#   W274#   W275#   W276#   W277#   W278#   
# W279#   W280#   W311#   W313#   W314#   W315#   W316#   W317#   W318#   
# W319#   W320#   W321#   W322#   W323#   W328#   W330#   W331#   W332#   
# W333#   W334#   W335#   W336#   W337#   W338#   W339#   W340#   W341#   
# W342#   W343#   W344#   W345#   W346#   W347#   W348#   W349#   W350#   
# W351#   W352#   W353#   W354#   W355#   W356#   W357#   W358#   W359#   
# W360#   W361#   W362#   W363#   W364#   W365#   W366#   W367#   W368#   
# W369#   W370#   W371#   W372#   W373#   W374#   W375#   W376#   W377#   
# W378#   W379#   W380#   W411#   W413#   W414#   W415#   W416#   W417#   
# W418#   W419#   W420#   W421#   W422#   W423#   W428#   W430#   W431#   
# W432#   W433#   W434#   W435#   W436#   W437#   W438#   W439#   W440#   
# W441#   W442#   W443#   W444#   W445#   W446#   W447#   W448#   W449#   
# W450#   W451#   W452#   W453#   W454#   W455#   W456#   W457#   W458#   
# W459#   W460#   W461#   W462#   W463#   W464#   W465#   W466#   W467#   
# W468#   W469#   W470#   W471#   W472#   W473#   W474#   W475#   W476#   
# W477#   W478#   W479#   W480#   W511#   W512#   W514#   W515#   W516#   
# W517#   W518#   W519#   W520#   W521#   W522#   W523#   W524#   W525#   
# W526#   W527#   W528#   W529#   W530#   W531#   W532#   W533#   W534#   
# W535#   W536#   W537#   W538#   W539#   W540#   W541#   W543#   W544#   
# W545#   W546#   W547#   W548#   W549#   W550#   W611#   W612#   W614#   
# W615#   W616#   W617#   W618#   W619#   W620#   W621#   W622#   W623#   
# W624#   W625#   W626#   W627#   W628#   W629#   W630#   W631#   W632#   
# W633#   W634#   W635#   W636#   W637#   W638#   W639#   W640#   W641#   
# W643#   W644#   W645#   W646#   W647#   W648#   W649#   W650#   W711#   
# W712#   W714#   W715#   W716#   W717#   W718#   W719#   W720#   W721#   
# W722#   W723#   W724#   W725#   W726#   W727#   W728#   W729#   W730#   
# W731#   W732#   W733#   W734#   W735#   W736#   W737#   W738#   W739#   
# W740#   W741#   W743#   W744#   W745#   W746#   W747#   W748#   W749#   
# W750#   W811#   W812#   W814#   W815#   W816#   W817#   W818#   W819#   
# W820#   W821#   W822#   W823#   W824#   W825#   W826#   W827#   W828#   
# W829#   W830#   W831#   W832#   W833#   W834#   W835#   W836#   W837#   
# W838#   W839#   W840#   W841#   W843#   W844#   W845#   W846#   W847#   
# W848#   W849#   W850#   
#
# This subroutine was written by Brent Neal <brentn@users.sourceforge.net>
# Modified to support new TIAA-CREF webpages by Kevin Foss <kfoss@maine.edu> and Brent Neal
# Modified to support new 2012 TIAA-CREF webpages by Carl LaCombe <calcisme@gmail.com>
# Modified to support new 2020 TIAA webpages by Jeremy Volkening 

#
# TODO:
#
# The TIAA-CREF cgi allows you to specify the exact dates for which to retrieve
# price data. That functionality could be worked into this subroutine.
# Currently, we only grab the most recent price data.
#

sub tiaacref {

    my $quoter = shift;

    my @symbols = @_;
    return unless scalar @symbols;

    my %info;
    my $ua = $quoter->user_agent;

    # The TIAA data service wants a start and end date. To guarantee data,
    # ask for 7 days of quotes, and only take the first (most recent) one.
    my $end = localtime;
    my $start = $end - ONE_WEEK;

    #Need to fetch a session key first
    my $session_key;
    my $fail_msg;
    my $res = $ua->get( $TIAA_MAIN_URL );
    if (! $res->is_success) {
        $fail_msg = "Failed to fetch TIAA page from $TIAA_MAIN_URL. It may be"
          . " that the link has changed. HTTP status returned: "
          . $res->status_line;
    }
    else {
        if ($res->content =~ /\bMODKey=\'([^']+)'/) {
            $session_key = $1;
        }
        else {
            $fail_msg = "Failed to fetch session key from TIAA site. Please"
            . " contact the developers for further assistance."
        }
    }
    if (defined $fail_msg) {
        for my $symbol (@symbols) {
            $info{ $symbol, "success"  } = 0;
            $info{ $symbol, "errormsg" } = $fail_msg;
        }
        return %info if wantarray;
        return \%info;
    }

    SYMBOL:
    for my $symbol (@symbols) {

        my $payload = {
            xids            => [$symbol],
            exportType      => 'CSV',
            startDate       => $start->mdy,
            endDate         => $end->mdy,
            selectedDetails => '',
        };

        my $url = join '?',
            $TIAA_DATA_URL,
            $session_key,
        ;
        my $res = $ua->post($url, $payload);
        if (! $res->is_success) {
            $info{ $symbol, "success"  } = 0;
            $info{ $symbol, "errormsg" } = "There was an error fetching data"
              . " for $symbol. HTTP status returned: " . $res->status_line;
            next SYMBOL;
        }

        # Data returned is in UTF-16-encoded CSV. As we asked for a week of
        # data, successful queries will likely return multiple lines, but they
        # are sorted in descending chronological order so we can just take
        # the first one.
        my $csv = decode( 'UTF-16LE', $res->content );
        open my $stream, '<', \$csv;
        while (my $line = <$stream>) {

            chomp $line;
            my ($description, $price, $date) = split ',', $line;

            # if no data is found for the given symbol, no error is thrown
            # but the content returned contains a textual error message. In
            # this case, the latter fields will not be defined.
            if (! defined $date) {
                $info{ $symbol, "success"  } = 0;
                $info{ $symbol, "errormsg" } =
                    "Error retrieving quote for $symbol - no listing for this"
                  . " name found. Please check symbol and the two letter"
                  . " extension (if any)";
                next SYMBOL;
            }
            try {
                $date = Time::Piece->strptime($date, "%m/%d/%Y");
            } catch {
                $info{ $symbol, "success"  } = 0;
                $info{ $symbol, "errormsg" } =
                    "Error parsing date ($date) for $symbol. Please"
                  . " contact the developers for further assistance.";
                next SYMBOL;
            };
            $info{ $symbol, "success"  } = 1;
            $info{ $symbol, "symbol"   } = $symbol;
            $info{ $symbol, "exchange" } = "TIAA";
            $info{ $symbol, "name"     } = $description;
            $info{ $symbol, "nav"      } = $price;
            $info{ $symbol, "price"    } = $info{$symbol, "nav"};
            $info{ $symbol, "currency" } = "USD";
            $info{ $symbol, "method"   } = "tiaacref";
            $info{ $symbol, "isodate" }  = $date->ymd;
            $info{ $symbol, "date" }     = $date->mdy('/');
            $quoter->store_date(
                \%info,
                $symbol,
                {isodate => $date->ymd}
            );

            last; # IMPORTANT: don't parse older data!

        }

    }

    return %info if wantarray;
    return \%info;

}

1;

=head1 NAME

Finance::Quote::Tiaacref - Obtain quote from TIAA (formerly TIAA-CREF)

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %stockinfo = $q->fetch("tiaacref","TIAAreal");

=head1 DESCRIPTION

This module obtains information about TIAA-CREF managed funds.

This module is loaded by default on a Finance::Quote object.  It's
also possible to load it explicitly by passing "Tiaacref" in to the
argument list of Finance::Quote->new().

Information returned by this module is governed by TIAA's terms
and conditions.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::Tiaacref:
symbol, exchange, name, date, nav, price.

=head1 SEE ALSO

TIAA, L<http://www.tiaa.org>

=cut
