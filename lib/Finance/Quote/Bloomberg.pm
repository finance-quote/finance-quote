package Finance::Quote::Bloomberg;

use strict;

use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TreeBuilder;
use Encode;

# VERSION

use vars qw($BLOOMBERG_URL);

$BLOOMBERG_URL = 'https://www.bloomberg.com/quote/';

sub methods { return (bloomberg => \&bloomberg); }

{
  my @labels = qw/method last currency symbol isodate/;

  sub labels { return (bloomberg => \@labels); }
}

sub bloomberg {
  my $quoter  = shift;
  my @symbols = @_;

  return unless @symbols;
  my ($ua, $reply, $url, %funds, $te, $table, $row, @value_currency, $name);

  foreach my $symbol (@symbols) {
    $name = $symbol;
    $url  = $BLOOMBERG_URL;
    $url  = $url . $name;
    $ua   = LWP::UserAgent->new;
    my @ns_headers = (
        'User-Agent' => 'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:67.0) Gecko/20100101 Firefox/67.0', 
        'Referer' => 'https://www.bloomberg.com/',
        'Accept' => '*/*',
        'Accept-Encoding' => 'br', 
        'Accept-Language' => 'en-US,en;q=0.5',
        'Pragma' => 'no-cache', );
    $reply = $ua->get($url, @ns_headers);

    unless ($reply->is_success) {
      $funds{$symbol, "success"}  = 0;
      $funds{$symbol, "errormsg"} = "HTTP failure";
      next;
    }

    eval {
      my $tree  = HTML::TreeBuilder->new_from_content(decode_utf8 $reply->content);
      my $price = $tree->look_down(_tag=>'span', 'class'=>'priceText__1853e8a5')->as_text();
      my $curr  = $tree->look_down(_tag=>'span', 'class'=>'currency__defc7184')->as_text();
      my $date  = $tree->look_down(_tag=>'div', sub {defined($_[0]->attr('class')) and $_[0]->attr('class') =~ /time__/})->as_text();

      $price =~ s/,//g;
      $date = $1 if $date =~ m|([0-9]{1,2}/[0-9]{1,2}/[0-9]{4})|;

      $funds{$name, 'method'}   = 'bloomberg';
      $funds{$name, 'last'}     = $price;
      $funds{$name, 'currency'} = $curr;
      $funds{$name, 'symbol'}   = $name;

      $quoter->store_date(\%funds, $name, {usdate => $date});

      $funds{$name, 'success'}  = 1;
    };

    if ($@) {
      $funds{$symbol, "success"}  = 0;
      $funds{$symbol, "errormsg"} = "parse error";
    }
  }

  return %funds if wantarray;
  return \%funds;
}

1;

=head1 NAME

Finance::Quote::Bloomberg - Obtain fund prices from Bloomberg.com 

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %fundinfo = $q->fetch("bloomberg", "security");

=head1 DESCRIPTION

This module obtains information about fund prices from www.bloomberg.com.  

=head1 SECURITY NAME

The security string must match the format expected by the site, such as
'AAPL:US' not 'AAPL'.

=head1 LABELS RETURNED

Labels returned by this module include: last, currency, symbol, isodate

=head1 SEE ALSO

Finance::Quote

=cut
