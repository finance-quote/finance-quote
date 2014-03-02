#!/usr/bin/perl -w
#
# Example stock-ticker program.  Can look up stocks from multiple
# markets and return the results in local currency.
#
# Revision: 1.1 

use strict;
use Finance::Quote;

my $CURRENCY = "";
#my $CURRENCY = "GBP";	# Set preferred currency here, or empty string for
			# no conversion.

# Test funds from Andy Pino
#						 MEXID		 ISIN(sedol)	Name
my @AndyPinoFunds = ( [ "SPCOM",	"GB0031835118",	"JP Morgan Natural Resources A Acc" 		],
					  [	"FLSUKS",	"GB0030880255",	"JP Morgan UK Smaller Companies A Acc"		],
					  [	"FLESCC",	"GB0030881337",	"JP Morgan Europe Smaller Companies I Acc"	],
					  [	"SPASC",	"GB0030880032",	"JP Morgan US Smaller Companies A Acc"		],
					  [	"C5SAI",	"GB00B1XMSK57",	"JP Morgan Asia A Inc"						],
					  [	"SPFIGI",	"GB0008350869",	"JP Morgan Global High Yield Bond A Inc"	],
					  [	"F6SVI",	"GB0004124342",	"JP Morgan UK Strategic Equity Income A Inc"],
					  [	"SWHYCI",	"GB0031643892",	"Scottish Widows High Income Bond Inc"		]	);

#						 MEXID		 ISIN(sedol)	Name
my @MSadlerFunds  = ( [ "ELDFN",	"GB0031779019",	"AXA F/L Distribution Fund" 				],
					  [	"FIAM",		"GB0003865176",	"Fidelity American"							],
					  [	"FIAMSS",	"GB0003865390",	"Fidelity American Special Situations"		],
					  [	"FIEUOP",	"GB0003874913",	"Fidelity European Opportunities"			],
					  [	"FIHCS",	"LU0116931725",	"Fidelity Global Health Care A GBP"			],
					  [	"FIGSSA",	"GB00B196XG23",	"Fidelity Global Special Situations"		],
					  [	"FITS",		"LU0116926998",	"Fidelity Global Technology Fund A GBP"		],
					  [	"FIMNI",	"GB0003875324",	"Fidelity Moneybuilder UK Index"			],
					  [	"FIIPM",	"GB0033696674",	"Fidelity Multimanager Income Portfolio"	],
					  [	"FISS",		"GB0003875100",	"Fidelity Special Situations"				],
					  [	"SKAI",		"GB0030781909",	"Skandia Artemis Income"					], # no longer listed on ft.com
					  [	"SKNHI",	"GB0002665015",	"Skandia Newton Higher Income"				],
					  [	"SKIPC",	"GB0031108987",	"SK Invesco Perpetual Corporate Bond"		],
					  [	"SKIPD",	"GB00B01QZZ60",	"SK Invesco Perpetual Distribution"			],
					  [	"SKGFM",	"GB0004842737",	"SK Investec Cautious Managed"				]	);
					  
# The stocks array contains a set of array-references.  Each reference
# has the market as the first element, and a set of stocks thereafter.

my @STOCKS = ( 

#		[qw/yahoo_europe SL.L YAR.OL BG.L LLOY.L/], # Standard Life, British Gas, Lloyds
#		[qw/yahoo C/],								# Citigroup

# these are Andy Pino's funds...
        [qw/ukfunds 
                GB0031835118
                GB0030880255
                GB0030881337
                GB0030880032
                GB00B1XMSK57
                GB0008350869
                GB0004124342
                GB0031643892
                      			/],
# these are my Fidelity, Axa (now Friends Life) and Skandia (now Old Mutual) funds....
	    [qw/ukfunds 	
				GB0031779019
				GB0003865176
				GB0003865390 
				GB0003874913
				LU0116931725
				GB00B196XG23
				LU0116926998
				GB0003875324
				GB0033696674
				GB0003875100
				GB0030781909
				GB0002665015
				GB0031108987
				GB00B01QZZ60
				GB0004842737
								/]
	     );


# These define the format.  The first item in each pair is the label,
# the second is the printf-style formatting, the third is the width
# of the field (used in printing headers).

my @labels = (
		["symbol",	"%-13s",	13],
		["method",	"%-13s",	13],
	    ["name",	"%-50.49s", 50],
	    ["date",	"%-11s",  	11], 
	    ["time",  	"%-6s",   	 6],
		["currency","%8s",		 9],
	    ["price", 	"%10.2f",  	10],
	    ["net",		"%+10.2f",	10],
		["p_change","%+8.2f%%",  9],
#		["success",	"%2d",   	 8],
#	    ["last",  	"%8.2f",  	 8],
#	    ["high",  	"%8.2f",  	 8], 
#	    ["low",   	"%8.2f",  	 8],
#	    ["close", 	"%8.2f",  	 8], 
#	    ["volume",	"%10d",   	10]
										);

#my $REFRESH = 60;	# Seconds between refresh.

# --- END CONFIG SECTION ---

my $quoter = Finance::Quote->new();
my $clear  = `clear`;			# So we can clear the screen.

# Build our header.

my $header = "\t\t\t\tSTOCK REPORT" .($CURRENCY ? " ($CURRENCY)" : "") ."\n\n";
my $dash_line = "";
foreach my $tuple (@labels) {
	my ($name, undef, $width) = @$tuple;
	$header .= sprintf("%-".$width."s",uc($name));
	$dash_line .= sprintf("%-".$width.".".($width-1)."s","-"x100);
}

#$header .= "\n".("-"x119)."\n";
$header .= "\n".$dash_line."\n";

# Header is all built.  Looks beautiful.

$quoter->set_currency($CURRENCY) if $CURRENCY;	# Set default currency.

#for (;;) {	# For ever.
#	print $clear,$header;
	print "\n\n",$header;

	foreach my $stockset (@STOCKS) 
	{
		my ($exchange, @symbols) = @$stockset;
		my %info = $quoter->fetch($exchange,@symbols);
#		print %info,"\n";
		foreach my $symbol (@symbols) 
		{
#			next unless $info{$symbol,"success"}; # Skip failures.
			if ($info{$symbol,"success"})
			{
				foreach my $tuple (@labels) 
				{
					my ($label,$format) = @$tuple;
					printf $format,$info{$symbol,$label};
				}
			}
			else
			{
				printf "%-14s  *** FAILED ***  %-40.40s%-40.40s",$info{$symbol,"symbol"},
																 $info{$symbol,"name"},
																 $info{$symbol,"errormsg"};
			} 
			print "\n";
		}
	}
	print "\n\n";

#	sleep($REFRESH);
#}

__END__
