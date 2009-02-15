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
package Finance::Quote::Currencies;
use strict;
use warnings;

use base 'Exporter';

our @EXPORT_OK = qw( known_currencies fetch_live_currencies );

our $VERSION = '1.0';

# =======================================================================
# methods used by Finance::Quote to import public functions
sub methods { return ( known_currencies      => \&known_currencies
                     , fetch_live_currencies => \&fetch_live_currencies
                     );
}

sub labels { return () };

# =======================================================================
# The current static currency list.
# This list is generated using get_live_
my %currencies = ( ALL => { name => qq{Albanian Lek} }
                 , DZD => { name => qq{Algerian Dinar} }
                 , XAL => { name => qq{Aluminium Ounces} }
                 , ARS => { name => qq{Argentine Peso} }
                 , AWG => { name => qq{Aruba Florin} }
                 , AUD => { name => qq{Australian Dollar} }
                 , BSD => { name => qq{Bahamian Dollar} }
                 , BHD => { name => qq{Bahraini Dinar} }
                 , BDT => { name => qq{Bangladesh Taka} }
                 , BBD => { name => qq{Barbados Dollar} }
                 , BYR => { name => qq{Belarus Ruble} }
                 , BZD => { name => qq{Belize Dollar} }
                 , BMD => { name => qq{Bermuda Dollar} }
                 , BTN => { name => qq{Bhutan Ngultrum} }
                 , BOB => { name => qq{Bolivian Boliviano} }
                 , BWP => { name => qq{Botswana Pula} }
                 , BRL => { name => qq{Brazilian Real} }
                 , GBP => { name => qq{British Pound} }
                 , BND => { name => qq{Brunei Dollar} }
                 , BGN => { name => qq{Bulgarian Lev} }
                 , BIF => { name => qq{Burundi Franc} }
                 , KHR => { name => qq{Cambodia Riel} }
                 , CAD => { name => qq{Canadian Dollar} }
                 , CVE => { name => qq{Cape Verde Escudo} }
                 , KYD => { name => qq{Cayman Islands Dollar} }
                 , XOF => { name => qq{CFA Franc (BCEAO)} }
                 , XAF => { name => qq{CFA Franc (BEAC)} }
                 , CLP => { name => qq{Chilean Peso} }
                 , CNY => { name => qq{Chinese Yuan} }
                 , COP => { name => qq{Colombian Peso} }
                 , KMF => { name => qq{Comoros Franc} }
                 , XCP => { name => qq{Copper Pounds} }
                 , CRC => { name => qq{Costa Rica Colon} }
                 , HRK => { name => qq{Croatian Kuna} }
                 , CUP => { name => qq{Cuban Peso} }
                 , CYP => { name => qq{Cyprus Pound} }
                 , CZK => { name => qq{Czech Koruna} }
                 , DKK => { name => qq{Danish Krone} }
                 , DJF => { name => qq{Dijibouti Franc} }
                 , DOP => { name => qq{Dominican Peso} }
                 , XCD => { name => qq{East Caribbean Dollar} }
                 , ECS => { name => qq{Ecuador Sucre} }
                 , EGP => { name => qq{Egyptian Pound} }
                 , SVC => { name => qq{El Salvador Colon} }
                 , ERN => { name => qq{Eritrea Nakfa} }
                 , EEK => { name => qq{Estonian Kroon} }
                 , ETB => { name => qq{Ethiopian Birr} }
                 , EUR => { name => qq{Euro} }
                 , FKP => { name => qq{Falkland Islands Pound} }
                 , FJD => { name => qq{Fiji Dollar} }
                 , GMD => { name => qq{Gambian Dalasi} }
                 , GHC => { name => qq{Ghanian Cedi} }
                 , GIP => { name => qq{Gibraltar Pound} }
                 , XAU => { name => qq{Gold Ounces} }
                 , GTQ => { name => qq{Guatemala Quetzal} }
                 , GNF => { name => qq{Guinea Franc} }
                 , GYD => { name => qq{Guyana Dollar} }
                 , HTG => { name => qq{Haiti Gourde} }
                 , HNL => { name => qq{Honduras Lempira} }
                 , HKD => { name => qq{Hong Kong Dollar} }
                 , HUF => { name => qq{Hungarian Forint} }
                 , ISK => { name => qq{Iceland Krona} }
                 , INR => { name => qq{Indian Rupee} }
                 , IDR => { name => qq{Indonesian Rupiah} }
                 , IRR => { name => qq{Iran Rial} }
                 , IQD => { name => qq{Iraqi Dinar} }
                 , ILS => { name => qq{Israeli Shekel} }
                 , JMD => { name => qq{Jamaican Dollar} }
                 , JPY => { name => qq{Japanese Yen} }
                 , JOD => { name => qq{Jordanian Dinar} }
                 , KZT => { name => qq{Kazakhstan Tenge} }
                 , KES => { name => qq{Kenyan Shilling} }
                 , KRW => { name => qq{Korean Won} }
                 , KWD => { name => qq{Kuwaiti Dinar} }
                 , LAK => { name => qq{Lao Kip} }
                 , LVL => { name => qq{Latvian Lat} }
                 , LBP => { name => qq{Lebanese Pound} }
                 , LSL => { name => qq{Lesotho Loti} }
                 , LRD => { name => qq{Liberian Dollar} }
                 , LYD => { name => qq{Libyan Dinar} }
                 , LTL => { name => qq{Lithuanian Lita} }
                 , MOP => { name => qq{Macau Pataca} }
                 , MKD => { name => qq{Macedonian Denar} }
                 , MWK => { name => qq{Malawi Kwacha} }
                 , MYR => { name => qq{Malaysian Ringgit} }
                 , MVR => { name => qq{Maldives Rufiyaa} }
                 , MTL => { name => qq{Maltese Lira} }
                 , MRO => { name => qq{Mauritania Ougulya} }
                 , MUR => { name => qq{Mauritius Rupee} }
                 , MXN => { name => qq{Mexican Peso} }
                 , MDL => { name => qq{Moldovan Leu} }
                 , MNT => { name => qq{Mongolian Tugrik} }
                 , MAD => { name => qq{Moroccan Dirham} }
                 , MMK => { name => qq{Myanmar Kyat} }
                 , NAD => { name => qq{Namibian Dollar} }
                 , NPR => { name => qq{Nepalese Rupee} }
                 , ANG => { name => qq{Neth Antilles Guilder} }
                 , TRY => { name => qq{New Turkish Lira} }
                 , NZD => { name => qq{New Zealand Dollar} }
                 , NIO => { name => qq{Nicaragua Cordoba} }
                 , NGN => { name => qq{Nigerian Naira} }
                 , KPW => { name => qq{North Korean Won} }
                 , NOK => { name => qq{Norwegian Krone} }
                 , OMR => { name => qq{Omani Rial} }
                 , XPF => { name => qq{Pacific Franc} }
                 , PKR => { name => qq{Pakistani Rupee} }
                 , XPD => { name => qq{Palladium Ounces} }
                 , PAB => { name => qq{Panama Balboa} }
                 , PGK => { name => qq{Papua New Guinea Kina} }
                 , PYG => { name => qq{Paraguayan Guarani} }
                 , PEN => { name => qq{Peruvian Nuevo Sol} }
                 , PHP => { name => qq{Philippine Peso} }
                 , XPT => { name => qq{Platinum Ounces} }
                 , PLN => { name => qq{Polish Zloty} }
                 , QAR => { name => qq{Qatar Rial} }
                 , RON => { name => qq{Romanian New Leu} }
                 , RUB => { name => qq{Russian Rouble} }
                 , RWF => { name => qq{Rwanda Franc} }
                 , WST => { name => qq{Samoa Tala} }
                 , STD => { name => qq{Sao Tome Dobra} }
                 , SAR => { name => qq{Saudi Arabian Riyal} }
                 , SCR => { name => qq{Seychelles Rupee} }
                 , SLL => { name => qq{Sierra Leone Leone} }
                 , XAG => { name => qq{Silver Ounces} }
                 , SGD => { name => qq{Singapore Dollar} }
                 , SKK => { name => qq{Slovak Koruna} }
                 , SIT => { name => qq{Slovenian Tolar} }
                 , SBD => { name => qq{Solomon Islands Dollar} }
                 , SOS => { name => qq{Somali Shilling} }
                 , ZAR => { name => qq{South African Rand} }
                 , LKR => { name => qq{Sri Lanka Rupee} }
                 , SHP => { name => qq{St Helena Pound} }
                 , SDD => { name => qq{Sudanese Dinar} }
                 , SZL => { name => qq{Swaziland Lilageni} }
                 , SEK => { name => qq{Swedish Krona} }
                 , CHF => { name => qq{Swiss Franc} }
                 , SYP => { name => qq{Syrian Pound} }
                 , TWD => { name => qq{Taiwan Dollar} }
                 , TZS => { name => qq{Tanzanian Shilling} }
                 , THB => { name => qq{Thai Baht} }
                 , TOP => { name => qq{Tonga Pa'anga} }
                 , TTD => { name => qq{Trinidad&Tobago Dollar} }
                 , TND => { name => qq{Tunisian Dinar} }
                 , USD => { name => qq{U.S. Dollar} }
                 , AED => { name => qq{UAE Dirham} }
                 , UGX => { name => qq{Ugandan Shilling} }
                 , UAH => { name => qq{Ukraine Hryvnia} }
                 , UYU => { name => qq{Uruguayan New Peso} }
                 , VUV => { name => qq{Vanuatu Vatu} }
                 , VEB => { name => qq{Venezuelan Bolivar} }
                 , VND => { name => qq{Vietnam Dong} }
                 , YER => { name => qq{Yemen Riyal} }
                 , ZMK => { name => qq{Zambian Kwacha} }
                 , ZWD => { name => qq{Zimbabwe Dollar} }
                 );

# =======================================================================
# known_currencies (public function)
#
# This function returns the known currency list. This is based on the
# cached currency list in this module. Use fetch_live_currencies for the
# live list.
sub known_currencies {
  return \%currencies;
}

# =======================================================================
# fetch_live_currencies (public function)
#
# This function retrieved the live currency list from the Yahoo Finance
# website. This function should really only be used to test if the known
# currency list in this module is out of date.
sub fetch_live_currencies {
  warn "NotYetImplemented";
  return {};
}

1;

=head1 NAME

Finance::Quote::Currencies - List of currencies from Yahoo Finance

=head1 SYNOPSIS

    use Finance::Quote::Currencies;

    my $currencies = Finance::Quote::Currencies::known_currencies();

    # Grab the latest from Yahoo
    my $live_currencies = Finance::Quote::Currencies::fetch_live_currencies();

=head1 DESCRIPTION

This module provides a list of known currencies from Yahoo Currency Converter.

The converter website includes a list of known currencies - this module includes
a stored list 

=head1 LAST EXTRACT

The currency list stored in this module was last copied from the live site:

Sun Feb 15 18:01:12 GMT 2009

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or (at
your option) any later version.

Currency information fetched through this module is bound by
Yahoo!'s terms and conditons.

=head1 AUTHORS

  Bradley Dean <bjdean@bjdean.id.au>

=head1 SEE ALSO

Yahoo Currency Converter - http://uk.finance.yahoo.com/currency-converter

=cut
