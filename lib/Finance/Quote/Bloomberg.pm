package Finance::Quote::Bloomberg;
require 5.013002;

use strict;

use vars qw($VERSION $BLOOMBERG_URL);

use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TreeBuilder;

$VERSION = '0.2';
$BLOOMBERG_URL = 'https://www.bloomberg.com/quote/';

sub methods { return (bloomberg => \&bloomberg); }

{
  my @labels = qw/date isodate method source name currency price/;

  sub labels { return (bloomberg => \@labels); }
}

sub bloomberg {
  my $quoter  = shift;
  my @symbols = @_;

  return unless @symbols;
  my ($ua, $reply, $url, %funds, $te, $table, $row, @value_currency, $name);

  foreach my $symbol (@symbols) {
    $name = $symbol;
    $url = $BLOOMBERG_URL;
    $url = $url . $name;
    # $ua    = $quoter->user_agent;
    $ua = LWP::UserAgent->new;
    my @ns_headers = (
      'User-Agent' => 'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:67.0) Gecko/20100101 Firefox/67.0', 
#      'User-Agent' => 'Mozilla/5.0 (Linux; Android 6.0.1; SM-G532G Build/MMB29T) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/63.0.3239.83 Mobile Safari/537.36', 
      'Referer' => 'https://www.bloomberg.com/',
      'Accept' => '*/*',
      'Accept-Encoding' => 'br', 
      'Accept-Language' => 'en-US,en;q=0.5',
      'Pragma' => 'no-cache', );
    $reply = $ua->get($url, @ns_headers);
    # below used for debugging    
    # print $reply->content;
    unless ($reply->is_success) {
      foreach my $symbol (@symbols) {
        $funds{$symbol, "success"}  = 0;
        $funds{$symbol, "errormsg"} = "HTTP failure";
      }
	  return wantarray ? %funds : \%funds;
    }

    my $tree = HTML::TreeBuilder->new_from_content($reply->content);
    my @price_array = $tree -> look_down(_tag=>'span','class'=>'priceText__1853e8a5');
    my $price = @price_array[0]->as_text();#->attr('content');
    my @curr_array = $tree -> look_down(_tag=>'span','class'=>'currency__defc7184');
    my $curr = @curr_array[0]->as_text();#->attr('content');
    # my @date_array = $tree -> look_down(_tag=>'div','class'=>'time__94e24743');
    # my $date = @date_array[0]->as_text();#attr('content');
    # print $price;
    # print $curr;
    # print $date;


    $funds{$name, 'method'}   = 'bloomberg';
    $funds{$name, 'price'}    = $price;
    $funds{$name, 'currency'} = $curr;
    $funds{$name, 'success'}  = 1;
    $funds{$name, 'symbol'}  = $name;
    # US date format (mm/dd/yyyy) as defined in Quote.pm
    # Read the string from the end, because for Stocks it adds time at the
    # begining; but for mutual funds, not.
    # $quoter->store_date(\%funds, $name, {usdate => substr($date,-14,10)});
    $funds{$name, 'source'}   = 'Finance::Quote::Bloomberg';
    $funds{$name, 'name'}   = $name;
    $funds{$name, 'p_change'} = "";  # p_change is not retrieved (yet?)
    }


    # Check for undefined symbols
    foreach my $symbol (@symbols) {
      unless ($funds{$symbol, 'success'}) {
          $funds{$symbol, "success"}  = 0;
          $funds{$symbol, "errormsg"} = "Fund name not found";
      }
    }

  return %funds if wantarray;
  return \%funds;
}

1;

=head1 NAME

Finance::Quote::Bloomberg - Obtain fund prices the Fredrik way

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %fundinfo = $q->fetch("bloomberg","fund name");

=head1 DESCRIPTION

This module obtains information about fund prices from
www.bloomberg.com.

=head1 FUND NAMES

Use some smart fund name...

=head1 LABELS RETURNED

Information available from Bloomberg funds may include the following labels:
date method source name currency price. The prices are updated at the
end of each bank day.

=head1 SEE ALSO

Perhaps bloomberg?

=cut
