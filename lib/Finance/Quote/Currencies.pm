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
package Finance::Quote::Currencies;
use strict;
use warnings;
use utf8;

use base 'Exporter';
use vars qw/@EXPORT_OK  $CURRENCY_URL/;

use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;
use Encode qw(decode);
use Data::Dumper::Perltidy;

@EXPORT_OK = qw( known_currencies fetch_live_currencies );
# VERSION

$CURRENCY_URL = 'https://www.iban.com/currency-codes';

sub methods { return ( known_currencies      => \&known_currencies
                     , fetch_live_currencies => \&fetch_live_currencies
                     );
}

sub labels { return () };

my %currencies = (

    'AED' => {
        'country' => ['UNITED ARAB EMIRATES (THE)'],
        'name'    => 'UAE Dirham',
        'number'  => '784'
    },
    'AFN' => {
        'country' => ['AFGHANISTAN'],
        'name'    => 'Afghani',
        'number'  => '971'
    },
    'ALL' => {
        'country' => ['ALBANIA'],
        'name'    => 'Lek',
        'number'  => '008'
    },
    'AMD' => {
        'country' => ['ARMENIA'],
        'name'    => 'Armenian Dram',
        'number'  => '051'
    },
    'ANG' => {
        'country' => [
            'CURAÇAO',
            'SINT MAARTEN (DUTCH PART)'
        ],
        'name'    => 'Netherlands Antillean Guilder',
        'number'  => '532'
    },
    'AOA' => {
        'country' => ['ANGOLA'],
        'name'    => 'Kwanza',
        'number'  => '973'
    },
    'ARS' => {
        'country' => ['ARGENTINA'],
        'name'    => 'Argentine Peso',
        'number'  => '032'
    },
    'AUD' => {
        'country' => [
            'AUSTRALIA',
            'CHRISTMAS ISLAND',
            'COCOS (KEELING) ISLANDS (THE)',
            'HEARD ISLAND AND McDONALD ISLANDS',
            'KIRIBATI',
            'NAURU',
            'NORFOLK ISLAND',
            'TUVALU'
        ],
        'name'    => 'Australian Dollar',
        'number'  => '036'
    },
    'AWG' => {
        'country' => ['ARUBA'],
        'name'    => 'Aruban Florin',
        'number'  => '533'
    },
    'AZN' => {
        'country' => ['AZERBAIJAN'],
        'name'    => 'Azerbaijanian Manat',
        'number'  => '944'
    },
    'BAM' => {
        'country' => ['BOSNIA AND HERZEGOVINA'],
        'name'    => 'Convertible Mark',
        'number'  => '977'
    },
    'BBD' => {
        'country' => ['BARBADOS'],
        'name'    => 'Barbados Dollar',
        'number'  => '052'
    },
    'BDT' => {
        'country' => ['BANGLADESH'],
        'name'    => 'Taka',
        'number'  => '050'
    },
    'BGN' => {
        'country' => ['BULGARIA'],
        'name'    => 'Bulgarian Lev',
        'number'  => '975'
    },
    'BHD' => {
        'country' => ['BAHRAIN'],
        'name'    => 'Bahraini Dinar',
        'number'  => '048'
    },
    'BIF' => {
        'country' => ['BURUNDI'],
        'name'    => 'Burundi Franc',
        'number'  => '108'
    },
    'BMD' => {
        'country' => ['BERMUDA'],
        'name'    => 'Bermudian Dollar',
        'number'  => '060'
    },
    'BND' => {
        'country' => ['BRUNEI DARUSSALAM'],
        'name'    => 'Brunei Dollar',
        'number'  => '096'
    },
    'BOB' => {
        'country' => ['BOLIVIA (PLURINATIONAL STATE OF)'],
        'name'    => 'Boliviano',
        'number'  => '068'
    },
    'BOV' => {
        'country' => ['BOLIVIA (PLURINATIONAL STATE OF)'],
        'name'    => 'Mvdol',
        'number'  => '984'
    },
    'BRL' => {
        'country' => ['BRAZIL'],
        'name'    => 'Brazilian Real',
        'number'  => '986'
    },
    'BSD' => {
        'country' => ['BAHAMAS (THE)'],
        'name'    => 'Bahamian Dollar',
        'number'  => '044'
    },
    'BTN' => {
        'country' => ['BHUTAN'],
        'name'    => 'Ngultrum',
        'number'  => '064'
    },
    'BWP' => {
        'country' => ['BOTSWANA'],
        'name'    => 'Pula',
        'number'  => '072'
    },
    'BYN' => {
        'country' => ['BELARUS'],
        'name'    => 'Belarussian Ruble',
        'number'  => '933'
    },
    'BZD' => {
        'country' => ['BELIZE'],
        'name'    => 'Belize Dollar',
        'number'  => '084'
    },
    'CAD' => {
        'country' => ['CANADA'],
        'name'    => 'Canadian Dollar',
        'number'  => '124'
    },
    'CDF' => {
        'country' => ['CONGO (THE DEMOCRATIC REPUBLIC OF THE)'],
        'name'    => 'Congolese Franc',
        'number'  => '976'
    },
    'CHE' => {
        'country' => ['SWITZERLAND'],
        'name'    => 'WIR Euro',
        'number'  => '947'
    },
    'CHF' => {
        'country' => [
            'LIECHTENSTEIN',
            'SWITZERLAND'
        ],
        'name'    => 'Swiss Franc',
        'number'  => '756'
    },
    'CHW' => {
        'country' => ['SWITZERLAND'],
        'name'    => 'WIR Franc',
        'number'  => '948'
    },
    'CLF' => {
        'country' => ['CHILE'],
        'name'    => 'Unidad de Fomento',
        'number'  => '990'
    },
    'CLP' => {
        'country' => ['CHILE'],
        'name'    => 'Chilean Peso',
        'number'  => '152'
    },
    'CNY' => {
        'country' => ['CHINA'],
        'name'    => 'Yuan Renminbi',
        'number'  => '156'
    },
    'COP' => {
        'country' => ['COLOMBIA'],
        'name'    => 'Colombian Peso',
        'number'  => '170'
    },
    'COU' => {
        'country' => ['COLOMBIA'],
        'name'    => 'Unidad de Valor Real',
        'number'  => '970'
    },
    'CRC' => {
        'country' => ['COSTA RICA'],
        'name'    => 'Costa Rican Colon',
        'number'  => '188'
    },
    'CUC' => {
        'country' => ['CUBA'],
        'name'    => 'Peso Convertible',
        'number'  => '931'
    },
    'CUP' => {
        'country' => ['CUBA'],
        'name'    => 'Cuban Peso',
        'number'  => '192'
    },
    'CVE' => {
        'country' => ['CABO VERDE'],
        'name'    => 'Cabo Verde Escudo',
        'number'  => '132'
    },
    'CZK' => {
        'country' => ['CZECH REPUBLIC (THE)'],
        'name'    => 'Czech Koruna',
        'number'  => '203'
    },
    'DJF' => {
        'country' => ['DJIBOUTI'],
        'name'    => 'Djibouti Franc',
        'number'  => '262'
    },
    'DKK' => {
        'country' => [
            'DENMARK',
            'FAROE ISLANDS (THE)',
            'GREENLAND'
        ],
        'name'    => 'Danish Krone',
        'number'  => '208'
    },
    'DOP' => {
        'country' => ['DOMINICAN REPUBLIC (THE)'],
        'name'    => 'Dominican Peso',
        'number'  => '214'
    },
    'DZD' => {
        'country' => ['ALGERIA'],
        'name'    => 'Algerian Dinar',
        'number'  => '012'
    },
    'EGP' => {
        'country' => ['EGYPT'],
        'name'    => 'Egyptian Pound',
        'number'  => '818'
    },
    'ERN' => {
        'country' => ['ERITREA'],
        'name'    => 'Nakfa',
        'number'  => '232'
    },
    'ETB' => {
        'country' => ['ETHIOPIA'],
        'name'    => 'Ethiopian Birr',
        'number'  => '230'
    },
    'EUR' => {
        'country' => [
            'ÅLAND ISLANDS',
            'ANDORRA',
            'AUSTRIA',
            'BELGIUM',
            'CYPRUS',
            'ESTONIA',
            'EUROPEAN UNION',
            'FINLAND',
            'FRANCE',
            'FRENCH GUIANA',
            'FRENCH SOUTHERN TERRITORIES (THE)',
            'GERMANY',
            'GREECE',
            'GUADELOUPE',
            'HOLY SEE (THE)',
            'IRELAND',
            'ITALY',
            'LATVIA',
            'LITHUANIA',
            'LUXEMBOURG',
            'MALTA',
            'MARTINIQUE',
            'MAYOTTE',
            'MONACO',
            'MONTENEGRO',
            'NETHERLANDS (THE)',
            'PORTUGAL',
            'RÉUNION',
            'SAINT BARTHÉLEMY',
            'SAINT MARTIN (FRENCH PART)',
            'SAINT PIERRE AND MIQUELON',
            'SAN MARINO',
            'SLOVAKIA',
            'SLOVENIA',
            'SPAIN'
        ],
        'name'    => 'Euro',
        'number'  => '978'
    },
    'FJD' => {
        'country' => ['FIJI'],
        'name'    => 'Fiji Dollar',
        'number'  => '242'
    },
    'FKP' => {
        'country' => ['FALKLAND ISLANDS (THE) [MALVINAS]'],
        'name'    => 'Falkland Islands Pound',
        'number'  => '238'
    },
    'GBP' => {
        'country' => [
            'GUERNSEY',
            'ISLE OF MAN',
            'JERSEY',
            'UNITED KINGDOM OF GREAT BRITAIN AND NORTHERN IRELAND (THE)'
        ],
        'name'    => 'Pound Sterling',
        'number'  => '826'
    },
    'GEL' => {
        'country' => ['GEORGIA'],
        'name'    => 'Lari',
        'number'  => '981'
    },
    'GHS' => {
        'country' => ['GHANA'],
        'name'    => 'Ghana Cedi',
        'number'  => '936'
    },
    'GIP' => {
        'country' => ['GIBRALTAR'],
        'name'    => 'Gibraltar Pound',
        'number'  => '292'
    },
    'GMD' => {
        'country' => ['GAMBIA (THE)'],
        'name'    => 'Dalasi',
        'number'  => '270'
    },
    'GNF' => {
        'country' => ['GUINEA'],
        'name'    => 'Guinea Franc',
        'number'  => '324'
    },
    'GTQ' => {
        'country' => ['GUATEMALA'],
        'name'    => 'Quetzal',
        'number'  => '320'
    },
    'GYD' => {
        'country' => ['GUYANA'],
        'name'    => 'Guyana Dollar',
        'number'  => '328'
    },
    'HKD' => {
        'country' => ['HONG KONG'],
        'name'    => 'Hong Kong Dollar',
        'number'  => '344'
    },
    'HNL' => {
        'country' => ['HONDURAS'],
        'name'    => 'Lempira',
        'number'  => '340'
    },
    'HRK' => {
        'country' => ['CROATIA'],
        'name'    => 'Kuna',
        'number'  => '191'
    },
    'HTG' => {
        'country' => ['HAITI'],
        'name'    => 'Gourde',
        'number'  => '332'
    },
    'HUF' => {
        'country' => ['HUNGARY'],
        'name'    => 'Forint',
        'number'  => '348'
    },
    'IDR' => {
        'country' => ['INDONESIA'],
        'name'    => 'Rupiah',
        'number'  => '360'
    },
    'ILS' => {
        'country' => ['ISRAEL'],
        'name'    => 'New Israeli Sheqel',
        'number'  => '376'
    },
    'INR' => {
        'country' => [
            'BHUTAN',
            'INDIA'
        ],
        'name'    => 'Indian Rupee',
        'number'  => '356'
    },
    'IQD' => {
        'country' => ['IRAQ'],
        'name'    => 'Iraqi Dinar',
        'number'  => '368'
    },
    'IRR' => {
        'country' => ['IRAN (ISLAMIC REPUBLIC OF)'],
        'name'    => 'Iranian Rial',
        'number'  => '364'
    },
    'ISK' => {
        'country' => ['ICELAND'],
        'name'    => 'Iceland Krona',
        'number'  => '352'
    },
    'JMD' => {
        'country' => ['JAMAICA'],
        'name'    => 'Jamaican Dollar',
        'number'  => '388'
    },
    'JOD' => {
        'country' => ['JORDAN'],
        'name'    => 'Jordanian Dinar',
        'number'  => '400'
    },
    'JPY' => {
        'country' => ['JAPAN'],
        'name'    => 'Yen',
        'number'  => '392'
    },
    'KES' => {
        'country' => ['KENYA'],
        'name'    => 'Kenyan Shilling',
        'number'  => '404'
    },
    'KGS' => {
        'country' => ['KYRGYZSTAN'],
        'name'    => 'Som',
        'number'  => '417'
    },
    'KHR' => {
        'country' => ['CAMBODIA'],
        'name'    => 'Riel',
        'number'  => '116'
    },
    'KMF' => {
        'country' => ['COMOROS (THE)'],
        'name'    => 'Comoro Franc',
        'number'  => '174'
    },
    'KPW' => {
        'country' => ['KOREA (THE DEMOCRATIC PEOPLE’S REPUBLIC OF)'],
        'name'    => 'North Korean Won',
        'number'  => '408'
    },
    'KRW' => {
        'country' => ['KOREA (THE REPUBLIC OF)'],
        'name'    => 'Won',
        'number'  => '410'
    },
    'KWD' => {
        'country' => ['KUWAIT'],
        'name'    => 'Kuwaiti Dinar',
        'number'  => '414'
    },
    'KYD' => {
        'country' => ['CAYMAN ISLANDS (THE)'],
        'name'    => 'Cayman Islands Dollar',
        'number'  => '136'
    },
    'KZT' => {
        'country' => ['KAZAKHSTAN'],
        'name'    => 'Tenge',
        'number'  => '398'
    },
    'LAK' => {
        'country' => ['LAO PEOPLE’S DEMOCRATIC REPUBLIC (THE)'],
        'name'    => 'Kip',
        'number'  => '418'
    },
    'LBP' => {
        'country' => ['LEBANON'],
        'name'    => 'Lebanese Pound',
        'number'  => '422'
    },
    'LKR' => {
        'country' => ['SRI LANKA'],
        'name'    => 'Sri Lanka Rupee',
        'number'  => '144'
    },
    'LRD' => {
        'country' => ['LIBERIA'],
        'name'    => 'Liberian Dollar',
        'number'  => '430'
    },
    'LSL' => {
        'country' => ['LESOTHO'],
        'name'    => 'Loti',
        'number'  => '426'
    },
    'LYD' => {
        'country' => ['LIBYA'],
        'name'    => 'Libyan Dinar',
        'number'  => '434'
    },
    'MAD' => {
        'country' => [
            'MOROCCO',
            'WESTERN SAHARA'
        ],
        'name'    => 'Moroccan Dirham',
        'number'  => '504'
    },
    'MDL' => {
        'country' => ['MOLDOVA (THE REPUBLIC OF)'],
        'name'    => 'Moldovan Leu',
        'number'  => '498'
    },
    'MGA' => {
        'country' => ['MADAGASCAR'],
        'name'    => 'Malagasy Ariary',
        'number'  => '969'
    },
    'MKD' => {
        'country' => ['REPUBLIC OF NORTH MACEDONIA'],
        'name'    => 'Denar',
        'number'  => '807'
    },
    'MMK' => {
        'country' => ['MYANMAR'],
        'name'    => 'Kyat',
        'number'  => '104'
    },
    'MNT' => {
        'country' => ['MONGOLIA'],
        'name'    => 'Tugrik',
        'number'  => '496'
    },
    'MOP' => {
        'country' => ['MACAO'],
        'name'    => 'Pataca',
        'number'  => '446'
    },
    'MRU' => {
        'country' => ['MAURITANIA'],
        'name'    => 'Ouguiya',
        'number'  => '929'
    },
    'MUR' => {
        'country' => ['MAURITIUS'],
        'name'    => 'Mauritius Rupee',
        'number'  => '480'
    },
    'MVR' => {
        'country' => ['MALDIVES'],
        'name'    => 'Rufiyaa',
        'number'  => '462'
    },
    'MWK' => {
        'country' => ['MALAWI'],
        'name'    => 'Kwacha',
        'number'  => '454'
    },
    'MXN' => {
        'country' => ['MEXICO'],
        'name'    => 'Mexican Peso',
        'number'  => '484'
    },
    'MXV' => {
        'country' => ['MEXICO'],
        'name'    => 'Mexican Unidad de Inversion (UDI)',
        'number'  => '979'
    },
    'MYR' => {
        'country' => ['MALAYSIA'],
        'name'    => 'Malaysian Ringgit',
        'number'  => '458'
    },
    'MZN' => {
        'country' => ['MOZAMBIQUE'],
        'name'    => 'Mozambique Metical',
        'number'  => '943'
    },
    'NAD' => {
        'country' => ['NAMIBIA'],
        'name'    => 'Namibia Dollar',
        'number'  => '516'
    },
    'NGN' => {
        'country' => ['NIGERIA'],
        'name'    => 'Naira',
        'number'  => '566'
    },
    'NIO' => {
        'country' => ['NICARAGUA'],
        'name'    => 'Cordoba Oro',
        'number'  => '558'
    },
    'NOK' => {
        'country' => [
            'BOUVET ISLAND',
            'NORWAY',
            'SVALBARD AND JAN MAYEN'
        ],
        'name'    => 'Norwegian Krone',
        'number'  => '578'
    },
    'NPR' => {
        'country' => ['NEPAL'],
        'name'    => 'Nepalese Rupee',
        'number'  => '524'
    },
    'NZD' => {
        'country' => [
            'COOK ISLANDS (THE)',
            'NEW ZEALAND',
            'NIUE',
            'PITCAIRN',
            'TOKELAU'
        ],
        'name'    => 'New Zealand Dollar',
        'number'  => '554'
    },
    'OMR' => {
        'country' => ['OMAN'],
        'name'    => 'Rial Omani',
        'number'  => '512'
    },
    'PAB' => {
        'country' => ['PANAMA'],
        'name'    => 'Balboa',
        'number'  => '590'
    },
    'PEN' => {
        'country' => ['PERU'],
        'name'    => 'Nuevo Sol',
        'number'  => '604'
    },
    'PGK' => {
        'country' => ['PAPUA NEW GUINEA'],
        'name'    => 'Kina',
        'number'  => '598'
    },
    'PHP' => {
        'country' => ['PHILIPPINES (THE)'],
        'name'    => 'Philippine Peso',
        'number'  => '608'
    },
    'PKR' => {
        'country' => ['PAKISTAN'],
        'name'    => 'Pakistan Rupee',
        'number'  => '586'
    },
    'PLN' => {
        'country' => ['POLAND'],
        'name'    => 'Zloty',
        'number'  => '985'
    },
    'PYG' => {
        'country' => ['PARAGUAY'],
        'name'    => 'Guarani',
        'number'  => '600'
    },
    'QAR' => {
        'country' => ['QATAR'],
        'name'    => 'Qatari Rial',
        'number'  => '634'
    },
    'RON' => {
        'country' => ['ROMANIA'],
        'name'    => 'Romanian Leu',
        'number'  => '946'
    },
    'RSD' => {
        'country' => ['SERBIA'],
        'name'    => 'Serbian Dinar',
        'number'  => '941'
    },
    'RUB' => {
        'country' => ['RUSSIAN FEDERATION (THE)'],
        'name'    => 'Russian Ruble',
        'number'  => '643'
    },
    'RWF' => {
        'country' => ['RWANDA'],
        'name'    => 'Rwanda Franc',
        'number'  => '646'
    },
    'SAR' => {
        'country' => ['SAUDI ARABIA'],
        'name'    => 'Saudi Riyal',
        'number'  => '682'
    },
    'SBD' => {
        'country' => ['SOLOMON ISLANDS'],
        'name'    => 'Solomon Islands Dollar',
        'number'  => '090'
    },
    'SCR' => {
        'country' => ['SEYCHELLES'],
        'name'    => 'Seychelles Rupee',
        'number'  => '690'
    },
    'SDG' => {
        'country' => ['SUDAN (THE)'],
        'name'    => 'Sudanese Pound',
        'number'  => '938'
    },
    'SEK' => {
        'country' => ['SWEDEN'],
        'name'    => 'Swedish Krona',
        'number'  => '752'
    },
    'SGD' => {
        'country' => ['SINGAPORE'],
        'name'    => 'Singapore Dollar',
        'number'  => '702'
    },
    'SHP' => {
        'country' => ['SAINT HELENA, ASCENSION AND TRISTAN DA CUNHA'],
        'name'    => 'Saint Helena Pound',
        'number'  => '654'
    },
    'SLL' => {
        'country' => ['SIERRA LEONE'],
        'name'    => 'Leone',
        'number'  => '694'
    },
    'SOS' => {
        'country' => ['SOMALIA'],
        'name'    => 'Somali Shilling',
        'number'  => '706'
    },
    'SRD' => {
        'country' => ['SURINAME'],
        'name'    => 'Surinam Dollar',
        'number'  => '968'
    },
    'SSP' => {
        'country' => ['SOUTH SUDAN'],
        'name'    => 'South Sudanese Pound',
        'number'  => '728'
    },
    'STN' => {
        'country' => ['SAO TOME AND PRINCIPE'],
        'name'    => 'Dobra',
        'number'  => '930'
    },
    'SVC' => {
        'country' => ['EL SALVADOR'],
        'name'    => 'El Salvador Colon',
        'number'  => '222'
    },
    'SYP' => {
        'country' => ['SYRIAN ARAB REPUBLIC'],
        'name'    => 'Syrian Pound',
        'number'  => '760'
    },
    'SZL' => {
        'country' => ['SWAZILAND'],
        'name'    => 'Lilangeni',
        'number'  => '748'
    },
    'THB' => {
        'country' => ['THAILAND'],
        'name'    => 'Baht',
        'number'  => '764'
    },
    'TJS' => {
        'country' => ['TAJIKISTAN'],
        'name'    => 'Somoni',
        'number'  => '972'
    },
    'TMT' => {
        'country' => ['TURKMENISTAN'],
        'name'    => 'Turkmenistan New Manat',
        'number'  => '934'
    },
    'TND' => {
        'country' => ['TUNISIA'],
        'name'    => 'Tunisian Dinar',
        'number'  => '788'
    },
    'TOP' => {
        'country' => ['TONGA'],
        'name'    => 'Pa’anga',
        'number'  => '776'
    },
    'TRY' => {
        'country' => ['TURKEY'],
        'name'    => 'Turkish Lira',
        'number'  => '949'
    },
    'TTD' => {
        'country' => ['TRINIDAD AND TOBAGO'],
        'name'    => 'Trinidad and Tobago Dollar',
        'number'  => '780'
    },
    'TWD' => {
        'country' => ['TAIWAN (PROVINCE OF CHINA)'],
        'name'    => 'New Taiwan Dollar',
        'number'  => '901'
    },
    'TZS' => {
        'country' => ['TANZANIA, UNITED REPUBLIC OF'],
        'name'    => 'Tanzanian Shilling',
        'number'  => '834'
    },
    'UAH' => {
        'country' => ['UKRAINE'],
        'name'    => 'Hryvnia',
        'number'  => '980'
    },
    'UGX' => {
        'country' => ['UGANDA'],
        'name'    => 'Uganda Shilling',
        'number'  => '800'
    },
    'USD' => {
        'country' => [
            'AMERICAN SAMOA',
            'BONAIRE, SINT EUSTATIUS AND SABA',
            'BRITISH INDIAN OCEAN TERRITORY (THE)',
            'ECUADOR',
            'EL SALVADOR',
            'GUAM',
            'HAITI',
            'MARSHALL ISLANDS (THE)',
            'MICRONESIA (FEDERATED STATES OF)',
            'NORTHERN MARIANA ISLANDS (THE)',
            'PALAU',
            'PANAMA',
            'PUERTO RICO',
            'TIMOR-LESTE',
            'TURKS AND CAICOS ISLANDS (THE)',
            'UNITED STATES MINOR OUTLYING ISLANDS (THE)',
            'UNITED STATES OF AMERICA (THE)',
            'VIRGIN ISLANDS (BRITISH)',
            'VIRGIN ISLANDS (U.S.)'
        ],
        'name'    => 'US Dollar',
        'number'  => '840'
    },
    'USN' => {
        'country' => ['UNITED STATES OF AMERICA (THE)'],
        'name'    => 'US Dollar (Next day)',
        'number'  => '997'
    },
    'UYI' => {
        'country' => ['URUGUAY'],
        'name'    => 'Uruguay Peso en Unidades Indexadas (URUIURUI)',
        'number'  => '940'
    },
    'UYU' => {
        'country' => ['URUGUAY'],
        'name'    => 'Peso Uruguayo',
        'number'  => '858'
    },
    'UZS' => {
        'country' => ['UZBEKISTAN'],
        'name'    => 'Uzbekistan Sum',
        'number'  => '860'
    },
    'VEF' => {
        'country' => ['VENEZUELA (BOLIVARIAN REPUBLIC OF)'],
        'name'    => 'Bolivar',
        'number'  => '937'
    },
    'VND' => {
        'country' => ['VIET NAM'],
        'name'    => 'Dong',
        'number'  => '704'
    },
    'VUV' => {
        'country' => ['VANUATU'],
        'name'    => 'Vatu',
        'number'  => '548'
    },
    'WST' => {
        'country' => ['SAMOA'],
        'name'    => 'Tala',
        'number'  => '882'
    },
    'XAF' => {
        'country' => [
            'CAMEROON',
            'CENTRAL AFRICAN REPUBLIC (THE)',
            'CHAD',
            'CONGO (THE)',
            'EQUATORIAL GUINEA',
            'GABON'
        ],
        'name'    => 'CFA Franc BEAC',
        'number'  => '950'
    },
    'XCD' => {
        'country' => [
            'ANGUILLA',
            'ANTIGUA AND BARBUDA',
            'DOMINICA',
            'GRENADA',
            'MONTSERRAT',
            'SAINT KITTS AND NEVIS',
            'SAINT LUCIA',
            'SAINT VINCENT AND THE GRENADINES'
        ],
        'name'    => 'East Caribbean Dollar',
        'number'  => '951'
    },
    'XDR' => {
        'country' => ['INTERNATIONAL MONETARY FUND (IMF) '],
        'name'    => 'SDR (Special Drawing Right)',
        'number'  => '960'
    },
    'XOF' => {
        'country' => [
            'BENIN',
            'BURKINA FASO',
            'CÔTE D\'IVOIRE',
            'GUINEA-BISSAU',
            'MALI',
            'NIGER (THE)',
            'SENEGAL',
            'TOGO'
        ],
        'name'    => 'CFA Franc BCEAO',
        'number'  => '952'
    },
    'XPF' => {
        'country' => [
            'FRENCH POLYNESIA',
            'NEW CALEDONIA',
            'WALLIS AND FUTUNA'
        ],
        'name'    => 'CFP Franc',
        'number'  => '953'
    },
    'XSU' => {
        'country' => ['SISTEMA UNITARIO DE COMPENSACION REGIONAL DE PAGOS "SUCRE"'],
        'name'    => 'Sucre',
        'number'  => '994'
    },
    'XUA' => {
        'country' => ['MEMBER COUNTRIES OF THE AFRICAN DEVELOPMENT BANK GROUP'],
        'name'    => 'ADB Unit of Account',
        'number'  => '965'
    },
    'YER' => {
        'country' => ['YEMEN'],
        'name'    => 'Yemeni Rial',
        'number'  => '886'
    },
    'ZAR' => {
        'country' => [
            'LESOTHO',
            'NAMIBIA',
            'SOUTH AFRICA'
        ],
        'name'    => 'Rand',
        'number'  => '710'
    },
    'ZMW' => {
        'country' => ['ZAMBIA'],
        'name'    => 'Zambian Kwacha',
        'number'  => '967'
    },
    'ZWL' => {
        'country' => ['ZIMBABWE'],
        'name'    => 'Zimbabwe Dollar',
        'number'  => '932'
    },

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
  my $ua    = LWP::UserAgent->new();
  my $reply = $ua->request(GET $CURRENCY_URL);
  return unless $reply->is_success;

  my $te = HTML::TableExtract->new( headers => ['Country', 'Currency', 'Code', 'Number']);
  $te->parse(decode('UTF-8', $reply->content));
 
  my $ts = $te->first_table_found || die 'Currency table not found';
  my %result = ();
  foreach my $row ($ts->rows) {
    my ($country, $currency, $code, $number) = @$row;
    next unless defined $code;

    # some country names in the HTML source have multi-space breaks
    $country =~ s/ +/ /g;
  
    if (exists $result{$code}) {
      push(@{$result{$code}->{'country'}}, $country);
    }
    else {
      $result{$code} = {'name'    => $currency,
                        'country' => [$country],
                        'number'  => $number};
    }
  }

  return \%result;
}

unless (caller) {
  my $hash = fetch_live_currencies();
  $Data::Dumper::Sortkeys = 1;
  print Dumper $hash;
}

1;

=head1 NAME

Finance::Quote::Currencies - List of currencies from iban.com

=head1 SYNOPSIS

    use Finance::Quote::Currencies;

    my $currencies = Finance::Quote::Currencies::known_currencies();

    # Grab the latest list
    my $live_currencies = Finance::Quote::Currencies::fetchive_currencies();

=head1 DESCRIPTION

This module provides a list of known currencies from iban.com.

known_currencies returns a cached currency information stored in this module.

fetch_live_currencies is a function that fetches the latest currency information.

Both functions return a hash

    {CODE => {'name'    => 'Currency Name', 
              'country' => ['List of countries known to use this currency'],
              'number'  => 'ISO 4217 currency code'}}

=head1 CACHE DATE

The currency list stored in this module was last copied from the live site July
2019.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

Currency information fetched through this module is bound by terms and
conditons available at https://www.iban.com/terms.

=head1 AUTHORS

  Bradley Dean <bjdean@bjdean.id.au> - Original Yahoo version

=cut
