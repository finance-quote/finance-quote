#!/usr/bin/perl
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
# Author: Kamen Naydenov <pau4o@kamennn.eu>
# Revision: 0.7

package Finance::Quote::BSESofia;

use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;

use vars qw/$BSESofia_URL $VERSION/;

$VERSION = "0.7";

# Single share URL
$BSESofia_URL = 'http://www.bse-sofia.bg/?page=QuotesInfo&site_lang=en&code=';

# trading session results
# $BSESofia_URL = 'http://beis.bia-bg.com/bseinfo/lasttraded.php';
# $BSESofia_URL = 'http://www.bse-sofia.bg/?page=SessionResults';


sub methods {
    return (
        bulgaria => \&bsesofia_get,
        bsesofia => \&bsesofia_get,
        europe   => \&bsesofia_get
    );
}

{
    my @labels = qw(
        average currency date
        exchange isodate last
        method name nominal
        p_change success symbol volume);


    sub labels {
        return (
            bulgaria => \@labels,
            bsesofia => \@labels,
            europe   => \@labels
        );
    }
}

sub bsesofia_get {

  my $quoter = shift;   # The Finance::Quote object.

  my @stocks = @_;
  return unless @stocks;

  my (%info, $tableRow, $headerRow, $reportDate, @tableHeaders);

  my $ua = $quoter->user_agent; # This gives us a user-agent
  $ua->agent("Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.8.1.3) Gecko/20070310 Iceweasel/2.0.0.3 (Debian-2.0.0.3-1)");

  foreach my $stock (@stocks) {

      if ( checkForOldName($stock) ) {
          $info{$stock,"success"} = 0;
          $info{$stock,"errormsg"} = "Requested stock $stock was chaged to: " . checkForOldName($stock);
          next;
      }

      my $response = $ua->request(GET $BSESofia_URL . $stock);

      unless ($response->is_success) {
          foreach my $stock (@stocks) {
              $info{$stock,"success"} = 0;
              $info{$stock,"errormsg"} = "HTTP error";
          }
          next;
      }

      $info{$stock,'symbol'} = $stock;

      my $page = $response->content;

      if ( $page =~ /The security is inactive/is ) {
          $info{$stock,"success"} = 0;
          $info{$stock,"errormsg"} = "Requested security: $stock is inactive";
          next;
      }

      if ( $page =~ /Invalid BSE CODE/is ) {
          $info{$stock,"success"} = 0;
          $info{$stock,"errormsg"} = "Invalid security code";
          next;
      }

      if ($page =~ /official Market Bonds/is) {
          $tableRow = 2; # row with data that we fetch
          # ugly hack to close unclosed table tag
          $page =~
              s!(<table.+?Volume.+?Last.+?average.+?Change.+?<tr>.+?</tr>)
               !$1</table>!sx;
          @tableHeaders = qw/volume last average p_change/;
          # currency information is in FLASH!!!
          #TODO: get it from URL with SessionResults
          $info{$stock, "currency"} = "EUR";
      }
      else {
          $tableRow = 3;
          @tableHeaders = qw/volume high low last average p_change/;
          $info{$stock, "currency"} = "BGN";
      }
      $headerRow = $tableRow - 1; # row with headers

      if ($page =~ /Last trading session results and best current offers:\D*([0-9-]+)/) {
          $reportDate = valueClean($1);
      }

      $quoter->store_date(\%info, $stock, {isodate => $reportDate});

      my %headers = (
          symbol   => qr/BSE\s+Code/i,
          name     => qr/Issuer/i,
          nominal  => qr/Nominal/i,
          volume   => qr/Volume\s+\(lots\)/i,
          high     => qr/High/i,
          low      => qr/Low/i,
          last     => qr/Last/i,
          average  => qr/Weighted-average/i,
          p_change => qr/Change\s+\(%\)/i,
      );

      ########################
      # first top level table
      ########################
      my $te = HTML::TableExtract->new(
          depth => 0,
          count => 0,
      );

      $te->parse($page);

      # check that we are looking for right share
      my $share = $te->first_table_found->space(2,0);
      $share = valueClean($share);
      unless ($share =~ /$stock/i) {
          $info{$stock,"success"} = 0;
          $info{$stock,"errormsg"} = "Can't find info about $stock.";
          next;
      }

      my $table = $te->first_table_found();
      my $i = 0;

      foreach my $label (qw/symbol name nominal/) {
          my $cellContent = $table->space(2, $i);
          $cellContent = valueClean($cellContent);
          $info{$stock,$label} = $cellContent
              if $table->space(1, $i) =~ /$headers{$label}/;
          $i++;
      }

      undef $te;
      undef $table;
      $i = 0;
      ##################################################
      # table with information from last trading session
      ##################################################
      $te = HTML::TableExtract->new(
          depth => 0,
          count => 1,
      ); # second top level table

      $te->parse($page);

      $table = $te->first_table_found();
      foreach my $label (@tableHeaders) {
          unless ( ($label eq 'high') or ($label eq 'low') ) {
              my $cellContent = $table->space($tableRow, $i);
              $cellContent = valueClean($cellContent);
              $info{$stock,$label} = $cellContent
                  if $table->space($headerRow, $i) =~ /$headers{$label}/;
          }
          $i++;
      }

      if (
          ($info{$stock,'last'} eq '')
                                ||
          ($info{$stock,'last'} =~ /^0\.?0*$/)
      ) { # don't return success for stocks that are not traded
          # and make shure that Gnucash don't use values if we return success=0
          undef $info{$stock,'last'};
          undef $info{$stock,'date'};
          undef $info{$stock,'currency'};
          undef $info{$stock,'average'};
          undef $info{$stock,'volume'};
          undef $info{$stock,'p_change'};
          undef $info{$stock,'nominal'};
          undef $info{$stock,'name'};
          $info{$stock,'success'} = 0;
          $info{$stock,'errormsg'} = "Stock does not traded in last trade sesion.";
          next;
      }

      # fix values
      if ($info{$stock,'volume'} eq '') {
          $info{$stock,'volume'} = 0;
      }
      if ($info{$stock,'nominal'} =~ /\s/) {
          $info{$stock,'nominal'} =~ s/\s//g;
      }

      $info{$stock, "method"} = "bsesofia";
      $info{$stock, "exchange"} = "Bulgarian Stock Exchange";
      $info{$stock, "success"} = 1;
  }
  return wantarray() ? %info : \%info;
}

# utility functions
sub valueClean {
    my $value =  shift;
    $value =~ tr/\200-\377//d; # remove all non-ASCII characters
    $value =~ s/^\s*//;        # leading spaces
    $value =~ s/\s*$//;        # trailing spaces
    return $value;
}

########################################################################
# as of 16.06.2008 codes for all stocks are changed with launch of Xetra
########################################################################
sub checkForOldName {
    my $stockSymbol = uc shift;
    my %oldToNew = (
        ALB     => '6AB',      HUGO    => '6SE',      CCBRE   => '5CK',
        ALBHL   => '5ALB',     HFSI    => '6F2',      CAPM    => '5CQ',
        ALUM    => '6AM',      HSLB    => '6SV',      SOFCOM  => '6SO',
        ARBAN   => '4IV',      AKUMP   => '6AK',      LIAM    => '5L1',
        BALKL   => '4BN',      ALBA    => '6AV',      LUKE    => '5L2',
        BIOEK   => '54B',      ASKRE   => '6AN',      INVE    => '5IP',
        BIOV    => '53B',      BEROE   => '51M',      GHVMP   => '4GH',
        BLABT   => '55B',      BULVI   => '4BF',      MIZA    => '5MF',
        BRIB    => '5EC',      BZAH    => '4BZ',      PMAYU   => '4O8',
        BTH     => '57B',      DIAM    => '4DI',      RADO    => '5BE',
        BUKT    => '56B',      DOVUHL  => '5DOV',     RODSL   => '3RJ',
        BULTZ   => '4OC',      DRUPL   => '4DR',      ARMHL   => '4AF',
        BUROZ   => '4BO',      DUPBT   => '4DA',      HANKR   => '4KR',
        CCB     => '4CF',      FZLES   => '4F6',      LESPL   => '4L5',
        CHUG    => '59C',      HHI     => '4KT',      MEHPL   => '4NY',
        DAB     => '4DB',      IMMI    => '4IM',      SKTEH   => 'SKY',
        DEKOT   => '4DE',      KABIL   => '4KO',      GKZ     => 'BLKB',
        DJERM   => '4DZ',      KDN     => '3KN',      BAUTOB2 => '9EGA',
        DOBHL   => '4D9',      KMM     => '4KP',      MBBACB5 => '5BNC',
        DOBRO   => '4DO',      KREM    => '4KW',      SBPF    => '6SB',
        DRURA   => '4DU',      LACH    => '4KX',      ALPR1   => '6AL',
        EKOFT   => '4EQ',      MANU    => '4MC',      FFI     => '6F4',
        ELENI   => '4EW',      METY    => '5MD',      BGASCO  => '9IPA',
        ELHIM   => '52E',      MOMKR   => '5MR',      BFPP    => '6F3A',
        ELMA    => '56E',      MRTEX   => '4MJ',      DFUMM   => 'YMC1',
        ELPO    => '4EZ',      NEOH    => '3NB',      BALMAK  => '9E7A',
        ELTOS   => 'SL9',      NEZAV   => '3NC',      BBLL    => '9FBA',
        EMKA    => '57E',      ORGH    => '5ORG',     MEDIAS  => '5MS',
        ENKAB   => '59E',      PIRH    => '4PJ',      ALCR    => '6AC',
        FAZAN   => '4F5',      PLEBT   => '4PQ',      HWELL   => '4H8',
        FILEX   => '4F7',      PLOBT   => '4CV',      PRIMTUR => '5P5',
        FORM    => '4F8',      SLB     => '3JL',      DFEUR   => 'MFRA',
        GDBT    => '4GD',      STPRO   => '3JX',      BEH     => '9IQA',
        HES     => '4HE',      TRPIV   => '3TW',      BWEB    => '9IJA',
        HIDPN   => '4HY',      UPAC    => '3U9',      BETAP   => '9JIA',
        HIMKO   => '4CK',      VELB    => '4V6',      MONBAT  => '5MB',
        HMAS    => '4CJ',      YAVOP   => '3YP',      BENE2   => 'E4AB',
        INCEL   => '4PB',      YKOR    => '3ZY',      BRBBG2  => '9ILA',
        ININ    => '4IE',      EMPI    => '58E',      MBINVB2 => '9GQB',
        INTER   => '4IR',      KAU     => '4KU',      STREIT  => '6ST',
        ISPBT   => '4IS',      KONIS   => '4CU',      SOLID   => '6SI',
        IZGRE   => '4IZ',      MELKO   => '5MC',      BATUR2  => '9E9A',
        KNEZ    => '4KZ',      ODES    => '5ODE',     BBROSS  => '9FNA',
        KOTL    => '4KS',      PTILO   => '55P',      EUBG    => '4EH',
        KREP    => '4KV',      RAZHL   => '6R1',      EXPRO   => '5EX',
        LEV     => '3Z4',      TOVSH   => '3TQ',      SDPRO   => '6SR',
        LION    => '4L3',      CENHL   => '5SR',      LAGUNA  => '4W5',
        LOTOS   => '4L6',      SEVHL   => '6S8',      BHVAR   => '5V2A',
        LOVTU   => '4O9',      VZH     => '4V3',      BELA    => '9K2A',
        LOZOV   => '3ZO',      HCEN    => '6C8',      INO     => '5I4',
        MAK     => '4MK',      BCH     => '6B6',      BTBI5   => 'A27B',
        MBE     => 'MBZ',      INDF    => '5I5',      HREIT   => '5H4',
        MBSYS   => '5ML',      HDOM    => '5ND',      PLG     => '5P6',
        MCH     => '5MH',      HORINV  => '5O2',      TODOROF => '5T6',
        MDIKA   => '5MA',      HKOM    => '6C5',      FIA     => '4F4',
        MELHL   => '4MB',      HIKA    => '4I8',      BITDN   => '9XOA',
        MESBU   => '4MQ',      HGI     => '5G2',      HFSPV   => '5H3',
        MESSM   => '5MO',      HNVEK   => '6N3',      BTRINV  => '6TRA',
        METIZ   => '5MZ',      PNG     => '6P2',      BTRINV2 => '6TRB',
        METKA   => '5MP',      TBIRE   => '4PY',      KAO     => '6K1',
        METKE   => '5ME',      TBIEB   => '5TBA',     SOFCOM2 => '6SOA',
        MGEHL   => '5M8',      BITEX   => '5EB',      BFARIN  => '9KDA',
        MISK    => '4NZ',      MBFIB2  => '5F4A',     BNIKR   => 'A1AA',
        MOSTS   => '5MY',      KDSIC   => '5K2',      DFCCBA  => 'MF2A',
        OPTIC   => '3OO',      AROMA   => '6AR',      DFCCBL  => 'MFPA',
        ORFEY   => '3OR',      BPET    => '4PGA',     HBGF    => '4H7',
        ORGTE   => '3OA',      BRP     => '5BR',      CORP    => '6C9',
        ORIG    => '3OG',      SFILM   => '6SF',      FIB     => '5F4',
        OTZK    => '5OTZ',     METRON  => '6M1',      ERGC3   => '5ER',
        PALD    => '56P',      ELANEF  => '4ELB',     DFSIIF  => 'SMJ3',
        PAMPO   => '4PV',      SVNIK   => '6SN',      DFCCBG  => 'MFEA',
        PAZBT   => '4PZ',      MR3     => '6TM',      BBPB2   => '9FSB',
        PESRE   => '4PF',      ENRB    => '6EB',      BHNVEK  => '6N3A',
        PET     => '5PET',     ERH     => '6EG',      BHWELL  => '4H8A',
        PETHL   => '6S7',      GAZ     => '4O1',      DFDSKR  => '4DMC',
        PISHM   => 'PZL',      DZI     => '6D5',      NIS     => 'RSS',
        POBTV   => '54P',      PRA     => '5CJ',      DFFIN   => '3NPB',
        POLIM   => '51P',      BVH     => '5BV',      DFSPRE  => 'MSGA',
        POLYA   => '53R',      INS     => '5I3',      DFSPRO  => 'S43A',
        PRIBR   => '5P3',      ADVANC  => '5AZ',      LOMSKO  => '6L1',
        RDINA   => '3RW',      IBG     => '4IN',      PKAR    => '4PN',
        REKGA   => '3RD',      CAPTL   => '6C3',      ZGMM    => '3ZG',
        REKPL   => '4BX',      BMDOB   => '9IOA',     DSPED   => '4DP',
        REZER   => '3RN',      BMREIT  => '6BMA',     HDPAT   => '6H2',
        RILA    => '3RF',      BRUNO   => 'A1FA',     HSI     => '6S5',
        RILEN   => '4OB',      MBUBB   => '9IMB',     NITX    => '3NG',
        ROZA    => '4BH',      COLOS   => 'CL8',      TORGO   => 'TTV',
        ROZAH   => '3RX',      PELIKAN => '6KDA',     INTERL  => '6I1',
        SERKU   => '3JF',      BTC     => '5BT',      DFUSD   => '4ELD',
        SEVKO   => '3JG',      UBBBF   => '5UBA',     MBBACB4 => '5BNB',
        SEVTO   => '4BJ',      MBFIB3  => '5F4B',     BSTR    => '4BI',
        SFARM   => '3JR',      INTLL   => '6I2',      UNTD    => '5U7',
        SHERA   => '3ZB',      ERGC    => '6EA',      ZENIT   => 'Z3T',
        SHLIF   => '3Z7',      BUNB2   => '9IIA',     BIANOR  => '5BI',
        SHUBT   => '3JZ',      MBALZ2  => '9FRA',     SBS     => '6SP',
        SIMAT   => '3JI',      BDOV    => '6D2A',     BBPG    => '9FOA',
        SIRMA   => '3JJ',      BREF    => '5BU',      DEVIN   => '6D3',
        SKELN   => '3NJ',      DOMIN   => '4DF',      PRC     => 'PRQ',
        SLDEN   => '3JP',      AVBLD   => '4AO',      BFEEI   => '6EEA',
        SLIV    => '3JN',      ELARG   => '4EC',      BPIREOS => '9IKA',
        SLUCI   => '3JM',      ELHYF   => '4ELA',     SING    => '5SV',
        SMP     => '3JQ',      TRCRD   => '5T5',      BZARYA  => '4BUA',
        SOFBT   => '3JU',      WWW     => '45W',      DFTBIS  => '5TBE',
        STOM    => '3JW',      SAF     => '6S2',      CITY    => 'CDX',
        STRAB   => '3JY',      PARK    => '4PK',      GLOBEX  => 'GEA',
        STREM   => '6S9',      MBEIB   => '5ECA',     BHWELL2 => '4H8B',
        STROD   => '3Z8',      BMSHN   => 'A1QA',     PKB     => 'BLKC',
        SUN     => '3JO',      TERRA   => '4EJ',      KZ      => 'BLKD',
        SUTEX   => '3JE',      ATERA   => '6A6',      BELA2   => '9K2B',
        SVESL   => '3LX',      BENE    => 'E4AA',     FINI    => 'RRH',
        SVIL    => '3MZ',      DFTBID  => '5TBB',     BOARD   => '5BP',
        SVIST   => '3MV',      BTBI4   => 'A27A',     PCI     => 'PPO',
        TICHA   => 'AL1',      DFSP    => 'SPKA',     KPLOD   => '4KY',
        TOPL    => '3TV',      BHCB3   => '9RTB',     HNIC    => '6N2',
        TRAAV   => '42T',      BMSTZ   => 'A21A',     BZHB    => 'A31A',
        TRAPA   => '4TP',      BAUTOB4 => '9EGB',     DFIC    => 'MC4A',
        VAP     => '4V4',      ICPD    => '4IC',      DFIA    => 'MI1A',
        VAZHO   => '4VH',      QUAD    => '5Q1',      BTBIL2  => 'A29A',
        VEGA    => '4V8',      DFELA   => '4ELE',     EFFIN   => 'EF1',
        VELIN   => '4VE',      DFDSKS  => '4DMA',     ETR     => '5EO',
        VENEZ   => '4V7',      DFDSKB  => '4DMB',     BMETIZ  => '5MZA',
        VERY    => '4VT',      BSFARM  => 'A34A',     TRACE   => 'T57',
        VIDA    => '4VD',      BUBB2   => '9IMA',     DFPRO   => 'MSCA',
        VINVR   => '4VB',      DFBM1   => '5BH2',     CHIM    => '6C4',
        VIPOM   => '4VI',      BILA    => '9UFA',     BKRIS   => '9YJA',
        VPLOD   => '4V5',      BFINC   => '9M7A',     EXPAT   => 'ERQ',
        YAMB    => '3YN',      BBPB    => '9FSA',     BELA3   => '9K2C',
        YAVOV   => '3YR',      DFTBIC  => '5TBD',     BELA4   => '9K2D',
        ZAHZA   => '3Z9',      DFTBIH  => '5TBC',     DFELMM  => '4ELF',
        ZARYA   => '4BU',      DFUBBPA => '5UBB',     ZHBG    => 'T43',
        ZASKO   => '3ZA',      DFUBBPB => '5UBC',     BBLL2   => '9FBB',
        ZEM     => '55E',      DFCAPMX => 'C8A1',     DFSTR   => 'S44A',
        ZINOK   => '3ZI',      EURINS  => '5IC',      BEUBG   => '4EHA',
        ZKMO    => '3ZK',      ERGC2   => '6ER',      DOMOKAT => 'DOH',
        ZLP     => '3ZL',      BSKELN  => '3NJA',     DFACB   => 'MA4A',
        ZMMPZ   => '3ZD',      BMID2   => '5BH1',     DFACGC  => 'MA4B',
        AKBHL   => '4AN',      BABF    => '9E8A',     CITIP   => '4OY',
        BELOP   => '52B',      DFRBBF  => 'RTT1',     STOKP   => 'SW3',
        ELKA    => '53E',      DFRBFB  => '4R31',     BBPB3   => '9FSC',
        GAGBT   => '4PX',      DFRBMM  => '4R21',     CBAAMG  => 'C81',
        GAMA    => '4GA',      DFRBSF  => 'RTT2',     ENM     => 'E4A',
        HASBT   => '4H9',      HLEV    => '3Z3',      SFTRD   => 'SO5',
        IHLBL   => '4ID',      MBBPB3  => '9FSD',     BFLN    => '9MBA',
        KOPR    => '4KQ',      BACB    => '5BN',      BELARG  => '4ECA',
        LAVEN   => '4L4',      BBML    => '9FCA',     SPARKY  => 'SPV',
        MESKA   => '5MK',      BSKELN2 => '3NJB',     BICPD   => '4ICA',
        MSTRY   => '4MO',      BDOV2   => '6D2B',     BELA5   => '9K2E',
        NEFTHL  => '5L3',      DFKDE   => '6KDC',     DFBM4   => '5BH4',
        POLIG   => '52P',      DFKDB   => '6KDB',     DFBM5   => '5BH5',
        SERDI   => '3JH',      BFPI    => '9K3A',     BHCB5   => '9RTD',
        SERTR   => '5ES',      PREMIER => '4PR',      DFRBUSD => 'RTT3',
        SIMKO   => '3JK',      HCAP    => '6H1',      DFUSF   => '4ELG',
        TRANB   => '3TU',      LAND    => '5BD',      DFZFBF  => 'ZFAA',
        VELPA   => '4V9',      BCL     => '9INA',     AGR     => 'A72',
        VITAP   => '4VS',      DFSIHF  => 'SMJ2',     BETR2   => '5EOA',
        VRAT    => '4VR',      DFSIBF  => 'SMJ1',     AST     => 'AC2',
        ZAVMA   => '3ZM',      BAUTOB5 => '9EGC',     DFDSKI  => 'MDPA',
        AFH     => '6A9',      MBALZ3  => '9FRB',     MART    => 'MB1',
        BHC     => '5BA',      FEEI    => '6EE',      DALIA   => 'DAD',
        GAMZA   => '6S4',      ALOFMI  => '6A7',      BDBRI   => 'D1OA',
        HUG     => '4CG',      BFPI2   => '9K3B',     BEURL2  => 'E4LA',
        TCH     => 'T24',      DFBM3   => '5BH3',     ASEBT   => '6AD',
        HSOF    => '4HS',      DFNEW   => '3NPA',     ELMET   => '51E',
        HVAR    => '5V2',      BOMK    => 'A2QA',     HYDRO   => '4HI',
        KTEX    => '5KTE',     FPRP    => '6F1',      KMH     => '58B',
        BULSTH  => '5Y1',      BAGRI   => '9E6A',     STTEH   => '3JV',
        TRANSH  => '6B2',      BTRAN   => 'A2GA',     UNIM    => '3U8',
        HIK     => '4I9',      FTXCO   => '6SL',      VINAS   => '4VA',
        HRU     => '5R9',      BLK     => 'A19A',     NAD     => '6N1',
        HSTR    => '6S3',      ADVEQ   => '6A8',      HPLD    => '6P1',
        HIZO    => '5IZ',      BBACB2  => '5BNA',     AKTIV   => '5AX',
        HRZ     => '6R2',      CEEP    => '5CG',      FPP     => '6F3',
        HEKO    => '6EC',      UNIP    => '45U',      SFI     => '6S6',
        HZAG    => '5Z2',      BIG     => '6B5',      BIOA    => '4OE',
        HDD     => '4D8',      BSEA    => '6B4',      UFM     => '59X',
        HEKI    => '5EK',      TRINV   => '6TR',      BARCUS  => '57YA',
        HREP    => '6R3',      BHCB4   => '9RTC',     DFAB    => '4OFB',
        HKON    => '6C7',      AGROF   => '6AG',      DFAV    => '4OFA',
        HASK    => '6AS',      BIBILD  => '9RSA',     BPM     => '59W',
        KRS     => '5T3',      BBAST   => 'A32A',     ELG     => 'ELW',
    );
    return $oldToNew{$stockSymbol} ? $oldToNew{$stockSymbol} : 0;
}


=head1 NAME

Finance::Quote::BSESofia - Obtain quotes from the Bulgarian Stock Exchange.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %stockinfo = $q->fetch("bsesofia","5ALB"); # Only query BSESofia.
    %stockinfo = $q->fetch("bulgaria","5ALB"); # Fail-over to other sources OK.
    %stockinfo = $q->fetch("europe","5ALB");   # Fail-over to other sources OK.

=head1 DESCRIPTION

This module obtains information from the Bulgarian Stock Exchange
http://www.bse-sofia.bg/.

This module is loaded by default on a Finance::Quote object.  It is
also possible to load it explicity by placing "BSESofia" in the argument
list to Finance::Quote->new().

This module provides both the "bsesofia", "bulgaria" and "europe"
fetch methods.

Using the "bsesofia" method will guarantee that your information only
comes from the Bulgarian Stock Exchange. If you wish to have fail-over
methods to deliver information from future sources for Bulgarian
stocks, please use "bulgaria" or "europe" methods.

Information returned by this module is governed by the Bulgarian
Stock Exchange's terms and conditions.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::BSESofia:

    average  - Weighted-average from last trading session
    currency - BGN or EUR see L<BUGS>
    date     - Last Trade Date  (MM/DD/YY format)
    exchange - The exchange the information was obtained from
    isodate  - Last Trade Date  (YYYY-MM-DD format)
    last     - Price from last trading session
    method   - The module (as could be passed to fetch) which found this information.
    name     - Company or Mutual Fund Name
    nominal  - nominal value of the security
    p_change - Percent Change from previous day's close
    success  - Did the stock successfully return information? (true/false)
    symbol   - BSE Sofia code for security
    volume   - Volume traded on last trading session

Module will return 0 for success in case of:
    - Error when connecting to the source
    - Missing or zero value for the price of the last trading session
    - The absence of information on the security
    - Submission of an invalid security code
    - Security is inactive
    - Submission of a security code from the time before switching to the
      system Xetra (in this case, the new code will be indicated in the
      error message)


=head1 BUGS

There is no way to ask prices for bonds or shares, they are mixed.

Because information for currency is shown only in FLASH (.swf)
returned information for currency about bonds may be wrong. As a
general rule for bonds returned currency is EUR and for shares
it's BGN.

Currently only information from last traded session can be obtained.

=head1 COPYRIGHT

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or (at
your option) any later version.

Other copyrights and conditions may apply to data fetched through this
module.

=head1 AUTHORS

Kamen Naydenov <pau4o@kamennn.eu>

=head1 SEE ALSO

Bulgarian Stock Exchange, http://www.bse-sofia.bg/

Finance::Quote

=cut

1;
