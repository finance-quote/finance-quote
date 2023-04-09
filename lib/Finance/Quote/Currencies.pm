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

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';
use if DEBUG, 'Data::Dumper::Perltidy';

use base 'Exporter';
use vars qw/@EXPORT_OK  $CURRENCY_URL/;

use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;
use Encode qw(decode);

# VERSION

@EXPORT_OK = qw( known_currencies fetch_live_currencies );

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
        'code'    => 'AED',
        'number'  => '784'
    },
    'AFN' => {
        'country' => ['AFGHANISTAN'],
        'name'    => 'Afghani',
        'code'    => 'AFN',
        'number'  => '971'
    },
    'ALL' => {
        'country' => ['ALBANIA'],
        'name'    => 'Lek',
        'code'    => 'ALL',
        'number'  => '008'
    },
    'AMD' => {
        'country' => ['ARMENIA'],
        'name'    => 'Armenian Dram',
        'code'    => 'AMD',
        'number'  => '051'
    },
    'ANG' => {
        'country' => [
            'CURAÇAO',
            'SINT MAARTEN (DUTCH PART)'
        ],
        'name'    => 'Netherlands Antillean Guilder',
        'code'    => 'ANG',
        'number'  => '532'
    },
    'AOA' => {
        'country' => ['ANGOLA'],
        'name'    => 'Kwanza',
        'code'    => 'AOA',
        'number'  => '973'
    },
    'ARS' => {
        'country' => ['ARGENTINA'],
        'name'    => 'Argentine Peso',
        'code'    => 'ARS',
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
        'code'    => 'AUD',
        'number'  => '036'
    },
    'AWG' => {
        'country' => ['ARUBA'],
        'name'    => 'Aruban Florin',
        'code'    => 'AWG',
        'number'  => '533'
    },
    'AZN' => {
        'country' => ['AZERBAIJAN'],
        'name'    => 'Azerbaijanian Manat',
        'code'    => 'AZN',
        'number'  => '944'
    },
    'BAM' => {
        'country' => ['BOSNIA AND HERZEGOVINA'],
        'name'    => 'Convertible Mark',
        'code'    => 'BAM',
        'number'  => '977'
    },
    'BBD' => {
        'country' => ['BARBADOS'],
        'name'    => 'Barbados Dollar',
        'code'    => 'BBD',
        'number'  => '052'
    },
    'BDT' => {
        'country' => ['BANGLADESH'],
        'name'    => 'Taka',
        'code'    => 'BDT',
        'number'  => '050'
    },
    'BGN' => {
        'country' => ['BULGARIA'],
        'name'    => 'Bulgarian Lev',
        'code'    => 'BGN',
        'number'  => '975'
    },
    'BHD' => {
        'country' => ['BAHRAIN'],
        'name'    => 'Bahraini Dinar',
        'code'    => 'BHD',
        'number'  => '048'
    },
    'BIF' => {
        'country' => ['BURUNDI'],
        'name'    => 'Burundi Franc',
        'code'    => 'BIF',
        'number'  => '108'
    },
    'BMD' => {
        'country' => ['BERMUDA'],
        'name'    => 'Bermudian Dollar',
        'code'    => 'BMD',
        'number'  => '060'
    },
    'BND' => {
        'country' => ['BRUNEI DARUSSALAM'],
        'name'    => 'Brunei Dollar',
        'code'    => 'BND',
        'number'  => '096'
    },
    'BOB' => {
        'country' => ['BOLIVIA (PLURINATIONAL STATE OF)'],
        'name'    => 'Boliviano',
        'code'    => 'BOB',
        'number'  => '068'
    },
    'BOV' => {
        'country' => ['BOLIVIA (PLURINATIONAL STATE OF)'],
        'name'    => 'Mvdol',
        'code'    => 'BOV',
        'number'  => '984'
    },
    'BRL' => {
        'country' => ['BRAZIL'],
        'name'    => 'Brazilian Real',
        'code'    => 'BRL',
        'number'  => '986'
    },
    'BSD' => {
        'country' => ['BAHAMAS (THE)'],
        'name'    => 'Bahamian Dollar',
        'code'    => 'BSD',
        'number'  => '044'
    },
    'BTN' => {
        'country' => ['BHUTAN'],
        'name'    => 'Ngultrum',
        'code'    => 'BTN',
        'number'  => '064'
    },
    'BWP' => {
        'country' => ['BOTSWANA'],
        'name'    => 'Pula',
        'code'    => 'BWP',
        'number'  => '072'
    },
    'BYN' => {
        'country' => ['BELARUS'],
        'name'    => 'Belarussian Ruble',
        'code'    => 'BYN',
        'number'  => '933'
    },
    'BZD' => {
        'country' => ['BELIZE'],
        'name'    => 'Belize Dollar',
        'code'    => 'BZD',
        'number'  => '084'
    },
    'CAD' => {
        'country' => ['CANADA'],
        'name'    => 'Canadian Dollar',
        'code'    => 'CAD',
        'number'  => '124'
    },
    'CDF' => {
        'country' => ['CONGO (THE DEMOCRATIC REPUBLIC OF THE)'],
        'name'    => 'Congolese Franc',
        'code'    => 'CDF',
        'number'  => '976'
    },
    'CHE' => {
        'country' => ['SWITZERLAND'],
        'name'    => 'WIR Euro',
        'code'    => 'CHE',
        'number'  => '947'
    },
    'CHF' => {
        'country' => [
            'LIECHTENSTEIN',
            'SWITZERLAND'
        ],
        'name'    => 'Swiss Franc',
        'code'    => 'CHF',
        'number'  => '756'
    },
    'CHW' => {
        'country' => ['SWITZERLAND'],
        'name'    => 'WIR Franc',
        'code'    => 'CHW',
        'number'  => '948'
    },
    'CLF' => {
        'country' => ['CHILE'],
        'name'    => 'Unidad de Fomento',
        'code'    => 'CLF',
        'number'  => '990'
    },
    'CLP' => {
        'country' => ['CHILE'],
        'name'    => 'Chilean Peso',
        'code'    => 'CLP',
        'number'  => '152'
    },
    'CNY' => {
        'country' => ['CHINA'],
        'name'    => 'Yuan Renminbi',
        'code'    => 'CNY',
        'number'  => '156'
    },
    'COP' => {
        'country' => ['COLOMBIA'],
        'name'    => 'Colombian Peso',
        'code'    => 'COP',
        'number'  => '170'
    },
    'COU' => {
        'country' => ['COLOMBIA'],
        'name'    => 'Unidad de Valor Real',
        'code'    => 'COU',
        'number'  => '970'
    },
    'CRC' => {
        'country' => ['COSTA RICA'],
        'name'    => 'Costa Rican Colon',
        'code'    => 'CRC',
        'number'  => '188'
    },
    'CUC' => {
        'country' => ['CUBA'],
        'name'    => 'Peso Convertible',
        'code'    => 'CUC',
        'number'  => '931'
    },
    'CUP' => {
        'country' => ['CUBA'],
        'name'    => 'Cuban Peso',
        'code'    => 'CUP',
        'number'  => '192'
    },
    'CVE' => {
        'country' => ['CABO VERDE'],
        'name'    => 'Cabo Verde Escudo',
        'code'    => 'CVE',
        'number'  => '132'
    },
    'CZK' => {
        'country' => ['CZECH REPUBLIC (THE)'],
        'name'    => 'Czech Koruna',
        'code'    => 'CZK',
        'number'  => '203'
    },
    'DJF' => {
        'country' => ['DJIBOUTI'],
        'name'    => 'Djibouti Franc',
        'code'    => 'DJF',
        'number'  => '262'
    },
    'DKK' => {
        'country' => [
            'DENMARK',
            'FAROE ISLANDS (THE)',
            'GREENLAND'
        ],
        'name'    => 'Danish Krone',
        'code'    => 'DKK',
        'number'  => '208'
    },
    'DOP' => {
        'country' => ['DOMINICAN REPUBLIC (THE)'],
        'name'    => 'Dominican Peso',
        'code'    => 'DOP',
        'number'  => '214'
    },
    'DZD' => {
        'country' => ['ALGERIA'],
        'name'    => 'Algerian Dinar',
        'code'    => 'DZD',
        'number'  => '012'
    },
    'EGP' => {
        'country' => ['EGYPT'],
        'name'    => 'Egyptian Pound',
        'code'    => 'EGP',
        'number'  => '818'
    },
    'ERN' => {
        'country' => ['ERITREA'],
        'name'    => 'Nakfa',
        'code'    => 'ERN',
        'number'  => '232'
    },
    'ETB' => {
        'country' => ['ETHIOPIA'],
        'name'    => 'Ethiopian Birr',
        'code'    => 'ETB',
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
        'code'    => 'EUR',
        'number'  => '978'
    },
    'FJD' => {
        'country' => ['FIJI'],
        'name'    => 'Fiji Dollar',
        'code'    => 'FJD',
        'number'  => '242'
    },
    'FKP' => {
        'country' => ['FALKLAND ISLANDS (THE) [MALVINAS]'],
        'name'    => 'Falkland Islands Pound',
        'code'    => 'FKP',
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
        'code'    => 'GBP',
        'number'  => '826'
    },
    'GEL' => {
        'country' => ['GEORGIA'],
        'name'    => 'Lari',
        'code'    => 'GEL',
        'number'  => '981'
    },
    'GHS' => {
        'country' => ['GHANA'],
        'name'    => 'Ghana Cedi',
        'code'    => 'GHS',
        'number'  => '936'
    },
    'GIP' => {
        'country' => ['GIBRALTAR'],
        'name'    => 'Gibraltar Pound',
        'code'    => 'GIP',
        'number'  => '292'
    },
    'GMD' => {
        'country' => ['GAMBIA (THE)'],
        'name'    => 'Dalasi',
        'code'    => 'GMD',
        'number'  => '270'
    },
    'GNF' => {
        'country' => ['GUINEA'],
        'name'    => 'Guinea Franc',
        'code'    => 'GNF',
        'number'  => '324'
    },
    'GTQ' => {
        'country' => ['GUATEMALA'],
        'name'    => 'Quetzal',
        'code'    => 'GTQ',
        'number'  => '320'
    },
    'GYD' => {
        'country' => ['GUYANA'],
        'name'    => 'Guyana Dollar',
        'code'    => 'GYD',
        'number'  => '328'
    },
    'HKD' => {
        'country' => ['HONG KONG'],
        'name'    => 'Hong Kong Dollar',
        'code'    => 'HKD',
        'number'  => '344'
    },
    'HNL' => {
        'country' => ['HONDURAS'],
        'name'    => 'Lempira',
        'code'    => 'HNL',
        'number'  => '340'
    },
    'HRK' => {
        'country' => ['CROATIA'],
        'name'    => 'Kuna',
        'code'    => 'HRK',
        'number'  => '191'
    },
    'HTG' => {
        'country' => ['HAITI'],
        'name'    => 'Gourde',
        'code'    => 'HTG',
        'number'  => '332'
    },
    'HUF' => {
        'country' => ['HUNGARY'],
        'name'    => 'Forint',
        'code'    => 'HUF',
        'number'  => '348'
    },
    'IDR' => {
        'country' => ['INDONESIA'],
        'name'    => 'Rupiah',
        'code'    => 'IDR',
        'number'  => '360'
    },
    'ILS' => {
        'country' => ['ISRAEL'],
        'name'    => 'New Israeli Sheqel',
        'code'    => 'ILS',
        'number'  => '376'
    },
    'INR' => {
        'country' => [
            'BHUTAN',
            'INDIA'
        ],
        'name'    => 'Indian Rupee',
        'code'    => 'INR',
        'number'  => '356'
    },
    'IQD' => {
        'country' => ['IRAQ'],
        'name'    => 'Iraqi Dinar',
        'code'    => 'IQD',
        'number'  => '368'
    },
    'IRR' => {
        'country' => ['IRAN (ISLAMIC REPUBLIC OF)'],
        'name'    => 'Iranian Rial',
        'code'    => 'IRR',
        'number'  => '364'
    },
    'ISK' => {
        'country' => ['ICELAND'],
        'name'    => 'Iceland Krona',
        'code'    => 'ISK',
        'number'  => '352'
    },
    'JMD' => {
        'country' => ['JAMAICA'],
        'name'    => 'Jamaican Dollar',
        'code'    => 'JMD',
        'number'  => '388'
    },
    'JOD' => {
        'country' => ['JORDAN'],
        'name'    => 'Jordanian Dinar',
        'code'    => 'JOD',
        'number'  => '400'
    },
    'JPY' => {
        'country' => ['JAPAN'],
        'name'    => 'Yen',
        'code'    => 'JPY',
        'number'  => '392'
    },
    'KES' => {
        'country' => ['KENYA'],
        'name'    => 'Kenyan Shilling',
        'code'    => 'KES',
        'number'  => '404'
    },
    'KGS' => {
        'country' => ['KYRGYZSTAN'],
        'name'    => 'Som',
        'code'    => 'KGS',
        'number'  => '417'
    },
    'KHR' => {
        'country' => ['CAMBODIA'],
        'name'    => 'Riel',
        'code'    => 'KHR',
        'number'  => '116'
    },
    'KMF' => {
        'country' => ['COMOROS (THE)'],
        'name'    => 'Comoro Franc',
        'code'    => 'KMF',
        'number'  => '174'
    },
    'KPW' => {
        'country' => ['KOREA (THE DEMOCRATIC PEOPLE’S REPUBLIC OF)'],
        'name'    => 'North Korean Won',
        'code'    => 'KPW',
        'number'  => '408'
    },
    'KRW' => {
        'country' => ['KOREA (THE REPUBLIC OF)'],
        'name'    => 'Won',
        'code'    => 'KRW',
        'number'  => '410'
    },
    'KWD' => {
        'country' => ['KUWAIT'],
        'name'    => 'Kuwaiti Dinar',
        'code'    => 'KWD',
        'number'  => '414'
    },
    'KYD' => {
        'country' => ['CAYMAN ISLANDS (THE)'],
        'name'    => 'Cayman Islands Dollar',
        'code'    => 'KYD',
        'number'  => '136'
    },
    'KZT' => {
        'country' => ['KAZAKHSTAN'],
        'name'    => 'Tenge',
        'code'    => 'KZT',
        'number'  => '398'
    },
    'LAK' => {
        'country' => ['LAO PEOPLE’S DEMOCRATIC REPUBLIC (THE)'],
        'name'    => 'Kip',
        'code'    => 'LAK',
        'number'  => '418'
    },
    'LBP' => {
        'country' => ['LEBANON'],
        'name'    => 'Lebanese Pound',
        'code'    => 'LBP',
        'number'  => '422'
    },
    'LKR' => {
        'country' => ['SRI LANKA'],
        'name'    => 'Sri Lanka Rupee',
        'code'    => 'LKR',
        'number'  => '144'
    },
    'LRD' => {
        'country' => ['LIBERIA'],
        'name'    => 'Liberian Dollar',
        'code'    => 'LRD',
        'number'  => '430'
    },
    'LSL' => {
        'country' => ['LESOTHO'],
        'name'    => 'Loti',
        'code'    => 'LSL',
        'number'  => '426'
    },
    'LYD' => {
        'country' => ['LIBYA'],
        'name'    => 'Libyan Dinar',
        'code'    => 'LYD',
        'number'  => '434'
    },
    'MAD' => {
        'country' => [
            'MOROCCO',
            'WESTERN SAHARA'
        ],
        'name'    => 'Moroccan Dirham',
        'code'    => 'MAD',
        'number'  => '504'
    },
    'MDL' => {
        'country' => ['MOLDOVA (THE REPUBLIC OF)'],
        'name'    => 'Moldovan Leu',
        'code'    => 'MDL',
        'number'  => '498'
    },
    'MGA' => {
        'country' => ['MADAGASCAR'],
        'name'    => 'Malagasy Ariary',
        'code'    => 'MGA',
        'number'  => '969'
    },
    'MKD' => {
        'country' => ['REPUBLIC OF NORTH MACEDONIA'],
        'name'    => 'Denar',
        'code'    => 'MKD',
        'number'  => '807'
    },
    'MMK' => {
        'country' => ['MYANMAR'],
        'name'    => 'Kyat',
        'code'    => 'MMK',
        'number'  => '104'
    },
    'MNT' => {
        'country' => ['MONGOLIA'],
        'name'    => 'Tugrik',
        'code'    => 'MNT',
        'number'  => '496'
    },
    'MOP' => {
        'country' => ['MACAO'],
        'name'    => 'Pataca',
        'code'    => 'MOP',
        'number'  => '446'
    },
    'MRU' => {
        'country' => ['MAURITANIA'],
        'name'    => 'Ouguiya',
        'code'    => 'MRU',
        'number'  => '929'
    },
    'MUR' => {
        'country' => ['MAURITIUS'],
        'name'    => 'Mauritius Rupee',
        'code'    => 'MUR',
        'number'  => '480'
    },
    'MVR' => {
        'country' => ['MALDIVES'],
        'name'    => 'Rufiyaa',
        'code'    => 'MVR',
        'number'  => '462'
    },
    'MWK' => {
        'country' => ['MALAWI'],
        'name'    => 'Kwacha',
        'code'    => 'MWK',
        'number'  => '454'
    },
    'MXN' => {
        'country' => ['MEXICO'],
        'name'    => 'Mexican Peso',
        'code'    => 'MXN',
        'number'  => '484'
    },
    'MXV' => {
        'country' => ['MEXICO'],
        'name'    => 'Mexican Unidad de Inversion (UDI)',
        'code'    => 'MXV',
        'number'  => '979'
    },
    'MYR' => {
        'country' => ['MALAYSIA'],
        'name'    => 'Malaysian Ringgit',
        'code'    => 'MYR',
        'number'  => '458'
    },
    'MZN' => {
        'country' => ['MOZAMBIQUE'],
        'name'    => 'Mozambique Metical',
        'code'    => 'MZN',
        'number'  => '943'
    },
    'NAD' => {
        'country' => ['NAMIBIA'],
        'name'    => 'Namibia Dollar',
        'code'    => 'NAD',
        'number'  => '516'
    },
    'NGN' => {
        'country' => ['NIGERIA'],
        'name'    => 'Naira',
        'code'    => 'NGN',
        'number'  => '566'
    },
    'NIO' => {
        'country' => ['NICARAGUA'],
        'name'    => 'Cordoba Oro',
        'code'    => 'NIO',
        'number'  => '558'
    },
    'NOK' => {
        'country' => [
            'BOUVET ISLAND',
            'NORWAY',
            'SVALBARD AND JAN MAYEN'
        ],
        'name'    => 'Norwegian Krone',
        'code'    => 'NOK',
        'number'  => '578'
    },
    'NPR' => {
        'country' => ['NEPAL'],
        'name'    => 'Nepalese Rupee',
        'code'    => 'NPR',
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
        'code'    => 'NZD',
        'number'  => '554'
    },
    'OMR' => {
        'country' => ['OMAN'],
        'name'    => 'Rial Omani',
        'code'    => 'OMR',
        'number'  => '512'
    },
    'PAB' => {
        'country' => ['PANAMA'],
        'name'    => 'Balboa',
        'code'    => 'PAB',
        'number'  => '590'
    },
    'PEN' => {
        'country' => ['PERU'],
        'name'    => 'Nuevo Sol',
        'code'    => 'PEN',
        'number'  => '604'
    },
    'PGK' => {
        'country' => ['PAPUA NEW GUINEA'],
        'name'    => 'Kina',
        'code'    => 'PGK',
        'number'  => '598'
    },
    'PHP' => {
        'country' => ['PHILIPPINES (THE)'],
        'name'    => 'Philippine Peso',
        'code'    => 'PHP',
        'number'  => '608'
    },
    'PKR' => {
        'country' => ['PAKISTAN'],
        'name'    => 'Pakistan Rupee',
        'code'    => 'PKR',
        'number'  => '586'
    },
    'PLN' => {
        'country' => ['POLAND'],
        'name'    => 'Zloty',
        'code'    => 'PLN',
        'number'  => '985'
    },
    'PYG' => {
        'country' => ['PARAGUAY'],
        'name'    => 'Guarani',
        'code'    => 'PYG',
        'number'  => '600'
    },
    'QAR' => {
        'country' => ['QATAR'],
        'name'    => 'Qatari Rial',
        'code'    => 'QAR',
        'number'  => '634'
    },
    'RON' => {
        'country' => ['ROMANIA'],
        'name'    => 'Romanian Leu',
        'code'    => 'RON',
        'number'  => '946'
    },
    'RSD' => {
        'country' => ['SERBIA'],
        'name'    => 'Serbian Dinar',
        'code'    => 'RSD',
        'number'  => '941'
    },
    'RUB' => {
        'country' => ['RUSSIAN FEDERATION (THE)'],
        'name'    => 'Russian Ruble',
        'code'    => 'RUB',
        'number'  => '643'
    },
    'RWF' => {
        'country' => ['RWANDA'],
        'name'    => 'Rwanda Franc',
        'code'    => 'RWF',
        'number'  => '646'
    },
    'SAR' => {
        'country' => ['SAUDI ARABIA'],
        'name'    => 'Saudi Riyal',
        'code'    => 'SAR',
        'number'  => '682'
    },
    'SBD' => {
        'country' => ['SOLOMON ISLANDS'],
        'name'    => 'Solomon Islands Dollar',
        'code'    => 'SBD',
        'number'  => '090'
    },
    'SCR' => {
        'country' => ['SEYCHELLES'],
        'name'    => 'Seychelles Rupee',
        'code'    => 'SCR',
        'number'  => '690'
    },
    'SDG' => {
        'country' => ['SUDAN (THE)'],
        'name'    => 'Sudanese Pound',
        'code'    => 'SDG',
        'number'  => '938'
    },
    'SEK' => {
        'country' => ['SWEDEN'],
        'name'    => 'Swedish Krona',
        'code'    => 'SEK',
        'number'  => '752'
    },
    'SGD' => {
        'country' => ['SINGAPORE'],
        'name'    => 'Singapore Dollar',
        'code'    => 'SGD',
        'number'  => '702'
    },
    'SHP' => {
        'country' => ['SAINT HELENA, ASCENSION AND TRISTAN DA CUNHA'],
        'name'    => 'Saint Helena Pound',
        'code'    => 'SHP',
        'number'  => '654'
    },
    'SLL' => {
        'country' => ['SIERRA LEONE'],
        'name'    => 'Leone',
        'code'    => 'SLL',
        'number'  => '694'
    },
    'SOS' => {
        'country' => ['SOMALIA'],
        'name'    => 'Somali Shilling',
        'code'    => 'SOS',
        'number'  => '706'
    },
    'SRD' => {
        'country' => ['SURINAME'],
        'name'    => 'Surinam Dollar',
        'code'    => 'SRD',
        'number'  => '968'
    },
    'SSP' => {
        'country' => ['SOUTH SUDAN'],
        'name'    => 'South Sudanese Pound',
        'code'    => 'SSP',
        'number'  => '728'
    },
    'STN' => {
        'country' => ['SAO TOME AND PRINCIPE'],
        'name'    => 'Dobra',
        'code'    => 'STN',
        'number'  => '930'
    },
    'SVC' => {
        'country' => ['EL SALVADOR'],
        'name'    => 'El Salvador Colon',
        'code'    => 'SVC',
        'number'  => '222'
    },
    'SYP' => {
        'country' => ['SYRIAN ARAB REPUBLIC'],
        'name'    => 'Syrian Pound',
        'code'    => 'SYP',
        'number'  => '760'
    },
    'SZL' => {
        'country' => ['SWAZILAND'],
        'name'    => 'Lilangeni',
        'code'    => 'SZL',
        'number'  => '748'
    },
    'THB' => {
        'country' => ['THAILAND'],
        'name'    => 'Baht',
        'code'    => 'THB',
        'number'  => '764'
    },
    'TJS' => {
        'country' => ['TAJIKISTAN'],
        'name'    => 'Somoni',
        'code'    => 'TJS',
        'number'  => '972'
    },
    'TMT' => {
        'country' => ['TURKMENISTAN'],
        'name'    => 'Turkmenistan New Manat',
        'code'    => 'TMT',
        'number'  => '934'
    },
    'TND' => {
        'country' => ['TUNISIA'],
        'name'    => 'Tunisian Dinar',
        'code'    => 'TND',
        'number'  => '788'
    },
    'TOP' => {
        'country' => ['TONGA'],
        'name'    => 'Pa’anga',
        'code'    => 'TOP',
        'number'  => '776'
    },
    'TRY' => {
        'country' => ['TURKEY'],
        'name'    => 'Turkish Lira',
        'code'    => 'TRY',
        'number'  => '949'
    },
    'TTD' => {
        'country' => ['TRINIDAD AND TOBAGO'],
        'name'    => 'Trinidad and Tobago Dollar',
        'code'    => 'TTD',
        'number'  => '780'
    },
    'TWD' => {
        'country' => ['TAIWAN (PROVINCE OF CHINA)'],
        'name'    => 'New Taiwan Dollar',
        'code'    => 'TWD',
        'number'  => '901'
    },
    'TZS' => {
        'country' => ['TANZANIA, UNITED REPUBLIC OF'],
        'name'    => 'Tanzanian Shilling',
        'code'    => 'TZS',
        'number'  => '834'
    },
    'UAH' => {
        'country' => ['UKRAINE'],
        'name'    => 'Hryvnia',
        'code'    => 'UAH',
        'number'  => '980'
    },
    'UGX' => {
        'country' => ['UGANDA'],
        'name'    => 'Uganda Shilling',
        'code'    => 'UGX',
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
        'code'    => 'USD',
        'number'  => '840'
    },
    'USN' => {
        'country' => ['UNITED STATES OF AMERICA (THE)'],
        'name'    => 'US Dollar (Next day)',
        'code'    => 'USN',
        'number'  => '997'
    },
    'UYI' => {
        'country' => ['URUGUAY'],
        'name'    => 'Uruguay Peso en Unidades Indexadas (URUIURUI)',
        'code'    => 'UYI',
        'number'  => '940'
    },
    'UYU' => {
        'country' => ['URUGUAY'],
        'name'    => 'Peso Uruguayo',
        'code'    => 'UYU',
        'number'  => '858'
    },
    'UZS' => {
        'country' => ['UZBEKISTAN'],
        'name'    => 'Uzbekistan Sum',
        'code'    => 'UZS',
        'number'  => '860'
    },
    'VEF' => {
        'country' => ['VENEZUELA (BOLIVARIAN REPUBLIC OF)'],
        'name'    => 'Bolivar',
        'code'    => 'VEF',
        'number'  => '937'
    },
    'VND' => {
        'country' => ['VIET NAM'],
        'name'    => 'Dong',
        'code'    => 'VND',
        'number'  => '704'
    },
    'VUV' => {
        'country' => ['VANUATU'],
        'name'    => 'Vatu',
        'code'    => 'VUV',
        'number'  => '548'
    },
    'WST' => {
        'country' => ['SAMOA'],
        'name'    => 'Tala',
        'code'    => 'WST',
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
        'code'    => 'XAF',
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
        'code'    => 'XCD',
        'number'  => '951'
    },
    'XDR' => {
        'country' => ['INTERNATIONAL MONETARY FUND (IMF) '],
        'name'    => 'SDR (Special Drawing Right)',
        'code'    => 'XDR',
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
        'code'    => 'XOF',
        'number'  => '952'
    },
    'XPF' => {
        'country' => [
            'FRENCH POLYNESIA',
            'NEW CALEDONIA',
            'WALLIS AND FUTUNA'
        ],
        'name'    => 'CFP Franc',
        'code'    => 'XPF',
        'number'  => '953'
    },
    'XSU' => {
        'country' => ['SISTEMA UNITARIO DE COMPENSACION REGIONAL DE PAGOS "SUCRE"'],
        'name'    => 'Sucre',
        'code'    => 'XSU',
        'number'  => '994'
    },
    'XUA' => {
        'country' => ['MEMBER COUNTRIES OF THE AFRICAN DEVELOPMENT BANK GROUP'],
        'name'    => 'ADB Unit of Account',
        'code'    => 'XUA',
        'number'  => '965'
    },
    'YER' => {
        'country' => ['YEMEN'],
        'name'    => 'Yemeni Rial',
        'code'    => 'YER',
        'number'  => '886'
    },
    'ZAR' => {
        'country' => [
            'LESOTHO',
            'NAMIBIA',
            'SOUTH AFRICA'
        ],
        'name'    => 'Rand',
        'code'    => 'ZAR',
        'number'  => '710'
    },
    'ZMW' => {
        'country' => ['ZAMBIA'],
        'name'    => 'Zambian Kwacha',
        'code'    => 'ZMW',
        'number'  => '967'
    },
    'ZWL' => {
        'country' => ['ZIMBABWE'],
        'name'    => 'Zimbabwe Dollar',
        'code'    => 'ZWL',
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
  ### [<now>] Calling fetch_live_currencies with URL: $CURRENCY_URL
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
                        'code'    => $code,
                        'number'  => $number};
    }
  }

  if (DEBUG) {
    $Data::Dumper::Sortkeys = 1;
    ### result: \%result
  }

  return \%result;
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

The currency list stored in this module was last copied from the live site Oct
2020.

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
