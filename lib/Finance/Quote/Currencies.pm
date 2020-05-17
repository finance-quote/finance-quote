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

my %currencies = 
   ('AED' => {
        'country' => ['UNITED ARAB EMIRATES (THE)'],
        'name'    => 'UAE Dirham',
        'number'  => 'AED'
    },
    'AFN' => {
        'country' => ['AFGHANISTAN'],
        'name'    => 'Afghani',
        'number'  => 'AFN'
    },
    'ALL' => {
        'country' => ['ALBANIA'],
        'name'    => 'Lek',
        'number'  => 'ALL'
    },
    'AMD' => {
        'country' => ['ARMENIA'],
        'name'    => 'Armenian Dram',
        'number'  => 'AMD'
    },
    'ANG' => {
        'country' => [ "CURA\x{c7}AO", 'SINT MAARTEN (DUTCH PART)' ],
        'name'    => 'Netherlands Antillean Guilder',
        'number'  => 'ANG'
    },
    'AOA' => {
        'country' => ['ANGOLA'],
        'name'    => 'Kwanza',
        'number'  => 'AOA'
    },
    'ARS' => {
        'country' => ['ARGENTINA'],
        'name'    => 'Argentine Peso',
        'number'  => 'ARS'
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
        'name'   => 'Australian Dollar',
        'number' => 'AUD'
    },
    'AWG' => {
        'country' => ['ARUBA'],
        'name'    => 'Aruban Florin',
        'number'  => 'AWG'
    },
    'AZN' => {
        'country' => ['AZERBAIJAN'],
        'name'    => 'Azerbaijanian Manat',
        'number'  => 'AZN'
    },
    'BAM' => {
        'country' => ['BOSNIA AND HERZEGOVINA'],
        'name'    => 'Convertible Mark',
        'number'  => 'BAM'
    },
    'BBD' => {
        'country' => ['BARBADOS'],
        'name'    => 'Barbados Dollar',
        'number'  => 'BBD'
    },
    'BDT' => {
        'country' => ['BANGLADESH'],
        'name'    => 'Taka',
        'number'  => 'BDT'
    },
    'BGN' => {
        'country' => ['BULGARIA'],
        'name'    => 'Bulgarian Lev',
        'number'  => 'BGN'
    },
    'BHD' => {
        'country' => ['BAHRAIN'],
        'name'    => 'Bahraini Dinar',
        'number'  => 'BHD'
    },
    'BIF' => {
        'country' => ['BURUNDI'],
        'name'    => 'Burundi Franc',
        'number'  => 'BIF'
    },
    'BMD' => {
        'country' => ['BERMUDA'],
        'name'    => 'Bermudian Dollar',
        'number'  => 'BMD'
    },
    'BND' => {
        'country' => ['BRUNEI DARUSSALAM'],
        'name'    => 'Brunei Dollar',
        'number'  => 'BND'
    },
    'BOB' => {
        'country' => ['BOLIVIA (PLURINATIONAL STATE OF)'],
        'name'    => 'Boliviano',
        'number'  => 'BOB'
    },
    'BOV' => {
        'country' => ['BOLIVIA (PLURINATIONAL STATE OF)'],
        'name'    => 'Mvdol',
        'number'  => 'BOV'
    },
    'BRL' => {
        'country' => ['BRAZIL'],
        'name'    => 'Brazilian Real',
        'number'  => 'BRL'
    },
    'BSD' => {
        'country' => ['BAHAMAS (THE)'],
        'name'    => 'Bahamian Dollar',
        'number'  => 'BSD'
    },
    'BTN' => {
        'country' => ['BHUTAN'],
        'name'    => 'Ngultrum',
        'number'  => 'BTN'
    },
    'BWP' => {
        'country' => ['BOTSWANA'],
        'name'    => 'Pula',
        'number'  => 'BWP'
    },
    'BYN' => {
        'country' => ['BELARUS'],
        'name'    => 'Belarussian Ruble',
        'number'  => 'BYN'
    },
    'BZD' => {
        'country' => ['BELIZE'],
        'name'    => 'Belize Dollar',
        'number'  => 'BZD'
    },
    'CAD' => {
        'country' => ['CANADA'],
        'name'    => 'Canadian Dollar',
        'number'  => 'CAD'
    },
    'CDF' => {
        'country' => ['CONGO (THE DEMOCRATIC REPUBLIC OF THE)'],
        'name'    => 'Congolese Franc',
        'number'  => 'CDF'
    },
    'CHE' => {
        'country' => ['SWITZERLAND'],
        'name'    => 'WIR Euro',
        'number'  => 'CHE'
    },
    'CHF' => {
        'country' => [ 'LIECHTENSTEIN', 'SWITZERLAND' ],
        'name'    => 'Swiss Franc',
        'number'  => 'CHF'
    },
    'CHW' => {
        'country' => ['SWITZERLAND'],
        'name'    => 'WIR Franc',
        'number'  => 'CHW'
    },
    'CLF' => {
        'country' => ['CHILE'],
        'name'    => 'Unidad de Fomento',
        'number'  => 'CLF'
    },
    'CLP' => {
        'country' => ['CHILE'],
        'name'    => 'Chilean Peso',
        'number'  => 'CLP'
    },
    'CNY' => {
        'country' => ['CHINA'],
        'name'    => 'Yuan Renminbi',
        'number'  => 'CNY'
    },
    'COP' => {
        'country' => ['COLOMBIA'],
        'name'    => 'Colombian Peso',
        'number'  => 'COP'
    },
    'COU' => {
        'country' => ['COLOMBIA'],
        'name'    => 'Unidad de Valor Real',
        'number'  => 'COU'
    },
    'CRC' => {
        'country' => ['COSTA RICA'],
        'name'    => 'Costa Rican Colon',
        'number'  => 'CRC'
    },
    'CUC' => {
        'country' => ['CUBA'],
        'name'    => 'Peso Convertible',
        'number'  => 'CUC'
    },
    'CUP' => {
        'country' => ['CUBA'],
        'name'    => 'Cuban Peso',
        'number'  => 'CUP'
    },
    'CVE' => {
        'country' => ['CABO VERDE'],
        'name'    => 'Cabo Verde Escudo',
        'number'  => 'CVE'
    },
    'CZK' => {
        'country' => ['CZECH REPUBLIC (THE)'],
        'name'    => 'Czech Koruna',
        'number'  => 'CZK'
    },
    'DJF' => {
        'country' => ['DJIBOUTI'],
        'name'    => 'Djibouti Franc',
        'number'  => 'DJF'
    },
    'DKK' => {
        'country' => [ 'DENMARK', 'FAROE ISLANDS (THE)', 'GREENLAND' ],
        'name'    => 'Danish Krone',
        'number'  => 'DKK'
    },
    'DOP' => {
        'country' => ['DOMINICAN REPUBLIC (THE)'],
        'name'    => 'Dominican Peso',
        'number'  => 'DOP'
    },
    'DZD' => {
        'country' => ['ALGERIA'],
        'name'    => 'Algerian Dinar',
        'number'  => 'DZD'
    },
    'EGP' => {
        'country' => ['EGYPT'],
        'name'    => 'Egyptian Pound',
        'number'  => 'EGP'
    },
    'ERN' => {
        'country' => ['ERITREA'],
        'name'    => 'Nakfa',
        'number'  => 'ERN'
    },
    'ETB' => {
        'country' => ['ETHIOPIA'],
        'name'    => 'Ethiopian Birr',
        'number'  => 'ETB'
    },
    'EUR' => {
        'country' => [
            "\x{c5}LAND ISLANDS",                'ANDORRA',
            'AUSTRIA',                           'BELGIUM',
            'CYPRUS',                            'ESTONIA',
            'EUROPEAN UNION',                    'FINLAND',
            'FRANCE',                            'FRENCH GUIANA',
            'FRENCH SOUTHERN TERRITORIES (THE)', 'GERMANY',
            'GREECE',                            'GUADELOUPE',
            'HOLY SEE (THE)',                    'IRELAND',
            'ITALY',                             'LATVIA',
            'LITHUANIA',                         'LUXEMBOURG',
            'MALTA',                             'MARTINIQUE',
            'MAYOTTE',                           'MONACO',
            'MONTENEGRO',                        'NETHERLANDS (THE)',
            'PORTUGAL',                          "R\x{c9}UNION",
            "SAINT BARTH\x{c9}LEMY",             'SAINT MARTIN (FRENCH PART)',
            'SAINT PIERRE AND MIQUELON',         'SAN MARINO',
            'SLOVAKIA',                          'SLOVENIA',
            'SPAIN'
        ],
        'name'   => 'Euro',
        'number' => 'EUR'
    },
    'FJD' => {
        'country' => ['FIJI'],
        'name'    => 'Fiji Dollar',
        'number'  => 'FJD'
    },
    'FKP' => {
        'country' => ['FALKLAND ISLANDS (THE) [MALVINAS]'],
        'name'    => 'Falkland Islands Pound',
        'number'  => 'FKP'
    },
    'GBP' => {
        'country' => [
            'GUERNSEY', 'ISLE OF MAN', 'JERSEY',
            'UNITED KINGDOM OF GREAT BRITAIN AND NORTHERN IRELAND (THE)'
        ],
        'name'   => 'Pound Sterling',
        'number' => 'GBP'
    },
    'GEL' => {
        'country' => ['GEORGIA'],
        'name'    => 'Lari',
        'number'  => 'GEL'
    },
    'GHS' => {
        'country' => ['GHANA'],
        'name'    => 'Ghana Cedi',
        'number'  => 'GHS'
    },
    'GIP' => {
        'country' => ['GIBRALTAR'],
        'name'    => 'Gibraltar Pound',
        'number'  => 'GIP'
    },
    'GMD' => {
        'country' => ['GAMBIA (THE)'],
        'name'    => 'Dalasi',
        'number'  => 'GMD'
    },
    'GNF' => {
        'country' => ['GUINEA'],
        'name'    => 'Guinea Franc',
        'number'  => 'GNF'
    },
    'GTQ' => {
        'country' => ['GUATEMALA'],
        'name'    => 'Quetzal',
        'number'  => 'GTQ'
    },
    'GYD' => {
        'country' => ['GUYANA'],
        'name'    => 'Guyana Dollar',
        'number'  => 'GYD'
    },
    'HKD' => {
        'country' => ['HONG KONG'],
        'name'    => 'Hong Kong Dollar',
        'number'  => 'HKD'
    },
    'HNL' => {
        'country' => ['HONDURAS'],
        'name'    => 'Lempira',
        'number'  => 'HNL'
    },
    'HRK' => {
        'country' => ['CROATIA'],
        'name'    => 'Kuna',
        'number'  => 'HRK'
    },
    'HTG' => {
        'country' => ['HAITI'],
        'name'    => 'Gourde',
        'number'  => 'HTG'
    },
    'HUF' => {
        'country' => ['HUNGARY'],
        'name'    => 'Forint',
        'number'  => 'HUF'
    },
    'IDR' => {
        'country' => ['INDONESIA'],
        'name'    => 'Rupiah',
        'number'  => 'IDR'
    },
    'ILS' => {
        'country' => ['ISRAEL'],
        'name'    => 'New Israeli Sheqel',
        'number'  => 'ILS'
    },
    'INR' => {
        'country' => [ 'BHUTAN', 'INDIA' ],
        'name'    => 'Indian Rupee',
        'number'  => 'INR'
    },
    'IQD' => {
        'country' => ['IRAQ'],
        'name'    => 'Iraqi Dinar',
        'number'  => 'IQD'
    },
    'IRR' => {
        'country' => ['IRAN (ISLAMIC REPUBLIC OF)'],
        'name'    => 'Iranian Rial',
        'number'  => 'IRR'
    },
    'ISK' => {
        'country' => ['ICELAND'],
        'name'    => 'Iceland Krona',
        'number'  => 'ISK'
    },
    'JMD' => {
        'country' => ['JAMAICA'],
        'name'    => 'Jamaican Dollar',
        'number'  => 'JMD'
    },
    'JOD' => {
        'country' => ['JORDAN'],
        'name'    => 'Jordanian Dinar',
        'number'  => 'JOD'
    },
    'JPY' => {
        'country' => ['JAPAN'],
        'name'    => 'Yen',
        'number'  => 'JPY'
    },
    'KES' => {
        'country' => ['KENYA'],
        'name'    => 'Kenyan Shilling',
        'number'  => 'KES'
    },
    'KGS' => {
        'country' => ['KYRGYZSTAN'],
        'name'    => 'Som',
        'number'  => 'KGS'
    },
    'KHR' => {
        'country' => ['CAMBODIA'],
        'name'    => 'Riel',
        'number'  => 'KHR'
    },
    'KMF' => {
        'country' => ['COMOROS (THE)'],
        'name'    => 'Comoro Franc',
        'number'  => 'KMF'
    },
    'KPW' => {
        'country' => ["KOREA (THE DEMOCRATIC PEOPLE\x{2019}S REPUBLIC OF)"],
        'name'    => 'North Korean Won',
        'number'  => 'KPW'
    },
    'KRW' => {
        'country' => ['KOREA (THE REPUBLIC OF)'],
        'name'    => 'Won',
        'number'  => 'KRW'
    },
    'KWD' => {
        'country' => ['KUWAIT'],
        'name'    => 'Kuwaiti Dinar',
        'number'  => 'KWD'
    },
    'KYD' => {
        'country' => ['CAYMAN ISLANDS (THE)'],
        'name'    => 'Cayman Islands Dollar',
        'number'  => 'KYD'
    },
    'KZT' => {
        'country' => ['KAZAKHSTAN'],
        'name'    => 'Tenge',
        'number'  => 'KZT'
    },
    'LAK' => {
        'country' => ["LAO PEOPLE\x{2019}S DEMOCRATIC REPUBLIC (THE)"],
        'name'    => 'Kip',
        'number'  => 'LAK'
    },
    'LBP' => {
        'country' => ['LEBANON'],
        'name'    => 'Lebanese Pound',
        'number'  => 'LBP'
    },
    'LKR' => {
        'country' => ['SRI LANKA'],
        'name'    => 'Sri Lanka Rupee',
        'number'  => 'LKR'
    },
    'LRD' => {
        'country' => ['LIBERIA'],
        'name'    => 'Liberian Dollar',
        'number'  => 'LRD'
    },
    'LSL' => {
        'country' => ['LESOTHO'],
        'name'    => 'Loti',
        'number'  => 'LSL'
    },
    'LYD' => {
        'country' => ['LIBYA'],
        'name'    => 'Libyan Dinar',
        'number'  => 'LYD'
    },
    'MAD' => {
        'country' => [ 'MOROCCO', 'WESTERN SAHARA' ],
        'name'    => 'Moroccan Dirham',
        'number'  => 'MAD'
    },
    'MDL' => {
        'country' => ['MOLDOVA (THE REPUBLIC OF)'],
        'name'    => 'Moldovan Leu',
        'number'  => 'MDL'
    },
    'MGA' => {
        'country' => ['MADAGASCAR'],
        'name'    => 'Malagasy Ariary',
        'number'  => 'MGA'
    },
    'MKD' => {
        'country' => ['MACEDONIA (THE FORMER YUGOSLAV REPUBLIC OF)'],
        'name'    => 'Denar',
        'number'  => 'MKD'
    },
    'MMK' => {
        'country' => ['MYANMAR'],
        'name'    => 'Kyat',
        'number'  => 'MMK'
    },
    'MNT' => {
        'country' => ['MONGOLIA'],
        'name'    => 'Tugrik',
        'number'  => 'MNT'
    },
    'MOP' => {
        'country' => ['MACAO'],
        'name'    => 'Pataca',
        'number'  => 'MOP'
    },
    'MRU' => {
        'country' => ['MAURITANIA'],
        'name'    => 'Ouguiya',
        'number'  => 'MRU'
    },
    'MUR' => {
        'country' => ['MAURITIUS'],
        'name'    => 'Mauritius Rupee',
        'number'  => 'MUR'
    },
    'MVR' => {
        'country' => ['MALDIVES'],
        'name'    => 'Rufiyaa',
        'number'  => 'MVR'
    },
    'MWK' => {
        'country' => ['MALAWI'],
        'name'    => 'Kwacha',
        'number'  => 'MWK'
    },
    'MXN' => {
        'country' => ['MEXICO'],
        'name'    => 'Mexican Peso',
        'number'  => 'MXN'
    },
    'MXV' => {
        'country' => ['MEXICO'],
        'name'    => 'Mexican Unidad de Inversion (UDI)',
        'number'  => 'MXV'
    },
    'MYR' => {
        'country' => ['MALAYSIA'],
        'name'    => 'Malaysian Ringgit',
        'number'  => 'MYR'
    },
    'MZN' => {
        'country' => ['MOZAMBIQUE'],
        'name'    => 'Mozambique Metical',
        'number'  => 'MZN'
    },
    'NAD' => {
        'country' => ['NAMIBIA'],
        'name'    => 'Namibia Dollar',
        'number'  => 'NAD'
    },
    'NGN' => {
        'country' => ['NIGERIA'],
        'name'    => 'Naira',
        'number'  => 'NGN'
    },
    'NIO' => {
        'country' => ['NICARAGUA'],
        'name'    => 'Cordoba Oro',
        'number'  => 'NIO'
    },
    'NOK' => {
        'country' => [ 'BOUVET ISLAND', 'NORWAY', 'SVALBARD AND JAN MAYEN' ],
        'name'    => 'Norwegian Krone',
        'number'  => 'NOK'
    },
    'NPR' => {
        'country' => ['NEPAL'],
        'name'    => 'Nepalese Rupee',
        'number'  => 'NPR'
    },
    'NZD' => {
        'country' => [
            'COOK ISLANDS (THE)', 'NEW ZEALAND', 'NIUE', 'PITCAIRN', 'TOKELAU'
        ],
        'name'   => 'New Zealand Dollar',
        'number' => 'NZD'
    },
    'OMR' => {
        'country' => ['OMAN'],
        'name'    => 'Rial Omani',
        'number'  => 'OMR'
    },
    'PAB' => {
        'country' => ['PANAMA'],
        'name'    => 'Balboa',
        'number'  => 'PAB'
    },
    'PEN' => {
        'country' => ['PERU'],
        'name'    => 'Nuevo Sol',
        'number'  => 'PEN'
    },
    'PGK' => {
        'country' => ['PAPUA NEW GUINEA'],
        'name'    => 'Kina',
        'number'  => 'PGK'
    },
    'PHP' => {
        'country' => ['PHILIPPINES (THE)'],
        'name'    => 'Philippine Peso',
        'number'  => 'PHP'
    },
    'PKR' => {
        'country' => ['PAKISTAN'],
        'name'    => 'Pakistan Rupee',
        'number'  => 'PKR'
    },
    'PLN' => {
        'country' => ['POLAND'],
        'name'    => 'Zloty',
        'number'  => 'PLN'
    },
    'PYG' => {
        'country' => ['PARAGUAY'],
        'name'    => 'Guarani',
        'number'  => 'PYG'
    },
    'QAR' => {
        'country' => ['QATAR'],
        'name'    => 'Qatari Rial',
        'number'  => 'QAR'
    },
    'RON' => {
        'country' => ['ROMANIA'],
        'name'    => 'Romanian Leu',
        'number'  => 'RON'
    },
    'RSD' => {
        'country' => ['SERBIA'],
        'name'    => 'Serbian Dinar',
        'number'  => 'RSD'
    },
    'RUB' => {
        'country' => ['RUSSIAN FEDERATION (THE)'],
        'name'    => 'Russian Ruble',
        'number'  => 'RUB'
    },
    'RWF' => {
        'country' => ['RWANDA'],
        'name'    => 'Rwanda Franc',
        'number'  => 'RWF'
    },
    'SAR' => {
        'country' => ['SAUDI ARABIA'],
        'name'    => 'Saudi Riyal',
        'number'  => 'SAR'
    },
    'SBD' => {
        'country' => ['SOLOMON ISLANDS'],
        'name'    => 'Solomon Islands Dollar',
        'number'  => 'SBD'
    },
    'SCR' => {
        'country' => ['SEYCHELLES'],
        'name'    => 'Seychelles Rupee',
        'number'  => 'SCR'
    },
    'SDG' => {
        'country' => ['SUDAN (THE)'],
        'name'    => 'Sudanese Pound',
        'number'  => 'SDG'
    },
    'SEK' => {
        'country' => ['SWEDEN'],
        'name'    => 'Swedish Krona',
        'number'  => 'SEK'
    },
    'SGD' => {
        'country' => ['SINGAPORE'],
        'name'    => 'Singapore Dollar',
        'number'  => 'SGD'
    },
    'SHP' => {
        'country' => ['SAINT HELENA, ASCENSION AND TRISTAN DA CUNHA'],
        'name'    => 'Saint Helena Pound',
        'number'  => 'SHP'
    },
    'SLL' => {
        'country' => ['SIERRA LEONE'],
        'name'    => 'Leone',
        'number'  => 'SLL'
    },
    'SOS' => {
        'country' => ['SOMALIA'],
        'name'    => 'Somali Shilling',
        'number'  => 'SOS'
    },
    'SRD' => {
        'country' => ['SURINAME'],
        'name'    => 'Surinam Dollar',
        'number'  => 'SRD'
    },
    'SSP' => {
        'country' => ['SOUTH SUDAN'],
        'name'    => 'South Sudanese Pound',
        'number'  => 'SSP'
    },
    'STN' => {
        'country' => ['SAO TOME AND PRINCIPE'],
        'name'    => 'Dobra',
        'number'  => 'STN'
    },
    'SVC' => {
        'country' => ['EL SALVADOR'],
        'name'    => 'El Salvador Colon',
        'number'  => 'SVC'
    },
    'SYP' => {
        'country' => ['SYRIAN ARAB REPUBLIC'],
        'name'    => 'Syrian Pound',
        'number'  => 'SYP'
    },
    'SZL' => {
        'country' => ['SWAZILAND'],
        'name'    => 'Lilangeni',
        'number'  => 'SZL'
    },
    'THB' => {
        'country' => ['THAILAND'],
        'name'    => 'Baht',
        'number'  => 'THB'
    },
    'TJS' => {
        'country' => ['TAJIKISTAN'],
        'name'    => 'Somoni',
        'number'  => 'TJS'
    },
    'TMT' => {
        'country' => ['TURKMENISTAN'],
        'name'    => 'Turkmenistan New Manat',
        'number'  => 'TMT'
    },
    'TND' => {
        'country' => ['TUNISIA'],
        'name'    => 'Tunisian Dinar',
        'number'  => 'TND'
    },
    'TOP' => {
        'country' => ['TONGA'],
        'name'    => "Pa\x{2019}anga",
        'number'  => 'TOP'
    },
    'TRY' => {
        'country' => ['TURKEY'],
        'name'    => 'Turkish Lira',
        'number'  => 'TRY'
    },
    'TTD' => {
        'country' => ['TRINIDAD AND TOBAGO'],
        'name'    => 'Trinidad and Tobago Dollar',
        'number'  => 'TTD'
    },
    'TWD' => {
        'country' => ['TAIWAN (PROVINCE OF CHINA)'],
        'name'    => 'New Taiwan Dollar',
        'number'  => 'TWD'
    },
    'TZS' => {
        'country' => ['TANZANIA, UNITED REPUBLIC OF'],
        'name'    => 'Tanzanian Shilling',
        'number'  => 'TZS'
    },
    'UAH' => {
        'country' => ['UKRAINE'],
        'name'    => 'Hryvnia',
        'number'  => 'UAH'
    },
    'UGX' => {
        'country' => ['UGANDA'],
        'name'    => 'Uganda Shilling',
        'number'  => 'UGX'
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
        'name'   => 'US Dollar',
        'number' => 'USD'
    },
    'USN' => {
        'country' => ['UNITED STATES OF AMERICA (THE)'],
        'name'    => 'US Dollar (Next day)',
        'number'  => 'USN'
    },
    'UYI' => {
        'country' => ['URUGUAY'],
        'name'    => 'Uruguay Peso en Unidades Indexadas (URUIURUI)',
        'number'  => 'UYI'
    },
    'UYU' => {
        'country' => ['URUGUAY'],
        'name'    => 'Peso Uruguayo',
        'number'  => 'UYU'
    },
    'UZS' => {
        'country' => ['UZBEKISTAN'],
        'name'    => 'Uzbekistan Sum',
        'number'  => 'UZS'
    },
    'VEF' => {
        'country' => ['VENEZUELA (BOLIVARIAN REPUBLIC OF)'],
        'name'    => 'Bolivar',
        'number'  => 'VEF'
    },
    'VND' => {
        'country' => ['VIET NAM'],
        'name'    => 'Dong',
        'number'  => 'VND'
    },
    'VUV' => {
        'country' => ['VANUATU'],
        'name'    => 'Vatu',
        'number'  => 'VUV'
    },
    'WST' => {
        'country' => ['SAMOA'],
        'name'    => 'Tala',
        'number'  => 'WST'
    },
    'XAF' => {
        'country' => [
            'CAMEROON',          'CENTRAL AFRICAN REPUBLIC (THE)',
            'CHAD',              'CONGO (THE)',
            'EQUATORIAL GUINEA', 'GABON'
        ],
        'name'   => 'CFA Franc BEAC',
        'number' => 'XAF'
    },
    'XCD' => {
        'country' => [
            'ANGUILLA',    'ANTIGUA AND BARBUDA',
            'DOMINICA',    'GRENADA',
            'MONTSERRAT',  'SAINT KITTS AND NEVIS',
            'SAINT LUCIA', 'SAINT VINCENT AND THE GRENADINES'
        ],
        'name'   => 'East Caribbean Dollar',
        'number' => 'XCD'
    },
    'XDR' => {
        'country' => ["INTERNATIONAL MONETARY FUND (IMF)\x{a0}"],
        'name'    => 'SDR (Special Drawing Right)',
        'number'  => 'XDR'
    },
    'XOF' => {
        'country' => [
            'BENIN',              'BURKINA FASO',
            "C\x{d4}TE D'IVOIRE", 'GUINEA-BISSAU',
            'MALI',               'NIGER (THE)',
            'SENEGAL',            'TOGO'
        ],
        'name'   => 'CFA Franc BCEAO',
        'number' => 'XOF'
    },
    'XPF' => {
        'country' =>
          [ 'FRENCH POLYNESIA', 'NEW CALEDONIA', 'WALLIS AND FUTUNA' ],
        'name'   => 'CFP Franc',
        'number' => 'XPF'
    },
    'XSU' => {
        'country' =>
          ['SISTEMA UNITARIO DE COMPENSACION REGIONAL DE PAGOS "SUCRE"'],
        'name'   => 'Sucre',
        'number' => 'XSU'
    },
    'XUA' => {
        'country' => ['MEMBER COUNTRIES OF THE AFRICAN DEVELOPMENT BANK GROUP'],
        'name'    => 'ADB Unit of Account',
        'number'  => 'XUA'
    },
    'YER' => {
        'country' => ['YEMEN'],
        'name'    => 'Yemeni Rial',
        'number'  => 'YER'
    },
    'ZAR' => {
        'country' => [ 'LESOTHO', 'NAMIBIA', 'SOUTH AFRICA' ],
        'name'    => 'Rand',
        'number'  => 'ZAR'
    },
    'ZMW' => {
        'country' => ['ZAMBIA'],
        'name'    => 'Zambian Kwacha',
        'number'  => 'ZMW'
    },
    'ZWL' => {
        'country' => ['ZIMBABWE'],
        'name'    => 'Zimbabwe Dollar',
        'number'  => 'ZWL'
    }
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
