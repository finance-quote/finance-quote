package Finance::Quote::Morningstar;
require 5.004;

use strict;

use vars qw($VERSION $MORNINGSTAR_SE_FUNDS_URL);

use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;

$VERSION = '1.16';
$MORNINGSTAR_SE_FUNDS_URL = 'http://morningstar.se/funds/overview.asp?cid=';

sub methods { return (morningstar => \&morningstar); }

{
  my @labels = qw/date isodate method source name currency price/;

  sub labels { return (morningstar => \@labels); }
}

sub morningstar {
  my $quoter  = shift;
  my @symbols = @_;

  return unless @symbols;
  my ($ua, $reply, $url, %funds, $te, $table, $row, @value_currency, $name);

  foreach my $symbol (@symbols) {
    $name = $symbol;
    $url = $MORNINGSTAR_SE_FUNDS_URL;
    $url = $url . $name;
    $ua    = $quoter->user_agent;
    $reply = $ua->request(GET $url);
    unless ($reply->is_success) {
	  foreach my $symbol (@symbols) {
        $funds{$symbol, "success"}  = 0;
        $funds{$symbol, "errormsg"} = "HTTP failure";
	  }
	  return wantarray ? %funds : \%funds;
    }

    $te = new HTML::TableExtract();
    $te->parse($reply->content);
    #print "Tables: " . $te->tables_report() . "\n";
    my $counter = 0;
    my $dateset = 0;
    for my $table ($te->tables()) {
	  for my $row ($table->rows()) {
        if (defined(@$row[0])) {
		  if ('Senaste NAV' eq substr(@$row[0],0,11)) {
            @value_currency = split(/ /, $$row[2]);
            $funds{$name, 'method'}   = 'morningstar_funds';
            $funds{$name, 'price'}    = $value_currency[0];
            $funds{$name, 'currency'} = $value_currency[1];
            $funds{$name, 'success'}  = 1;
            $funds{$name, 'symbol'}  = $name;
            $funds{$name, 'source'}   = 'Finance::Quote::Morningstar';
            $funds{$name, 'name'}   = $name;
            $funds{$name, 'p_change'} = "";  # p_change is not retrieved (yet?)
		  }
		  if ($counter == 7 && $dateset == 0) {
            my $date = substr($$row[1],0,10);
            $quoter->store_date(\%funds, $name, {isodate => $date});
            $dateset = 1;
		  }
        }
	  }
	  $counter++;
    }

    # Check for undefined symbols
    foreach my $symbol (@symbols) {
	  unless ($funds{$symbol, 'success'}) {
        $funds{$symbol, "success"}  = 0;
        $funds{$symbol, "errormsg"} = "Fund name not found";
	  }
    }
  }
  return %funds if wantarray;
  return \%funds;
}

1;

=head1 NAME

Finance::Quote::Morningstar - Obtain fund prices the Fredrik way

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %fundinfo = $q->fetch("morningstar","fund name");

=head1 DESCRIPTION

This module obtains information about Fredrik fund prices from
www.morningstar.se.

=head1 FUND NAMES

Use some smart fund name...

=head1 LABELS RETURNED

Information available from Fredrik funds may include the following labels:
date method source name currency price. The prices are updated at the
end of each bank day.

=head1 SEE ALSO

Perhaps morningstar?

=cut
