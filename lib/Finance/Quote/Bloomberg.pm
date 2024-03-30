package Finance::Quote::Bloomberg;

use strict;

use LWP::UserAgent;
use HTTP::Request::Common;
use HTTP::CookieJar::LWP ();
use HTML::TreeBuilder;
use Encode;
use JSON;

# VERSION

use vars qw($BLOOMBERG_URL);

$BLOOMBERG_URL = 'https://www.bloomberg.com/quote/';

sub methods { return (bloomberg => \&bloomberg); }

{
  my @labels = qw/method name last currency symbol isodate/;

  sub labels { return (bloomberg => \@labels); }
}

sub bloomberg {
  my $quoter  = shift;
  my @symbols = @_;

  return unless @symbols;
  my ($ua, $cj, $reply, $url, %funds, $te, $table, $row, @value_currency, $name);

  foreach my $symbol (@symbols) {
    $name = $symbol;
    $url  = $BLOOMBERG_URL;
    $url  = $url . $name;
    $cj   = HTTP::CookieJar::LWP->new;
    $ua   = LWP::UserAgent->new(cookie_jar => $cj);
    my @ns_headers = (
        'User-Agent' => 'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:67.0) Gecko/20100101 Firefox/67.0', 
        'Referer' => 'https://www.bloomberg.com/',
        'Accept' => '*/*',
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
      my $json = encode_utf8 (($tree->look_down(_tag=>'script', 'id'=>'__NEXT_DATA__')->content_list())[0]);
      my $json_decoded = decode_json $json;
      my $json_quote = $json_decoded->{'props'}{'pageProps'}{'quote'};
      my $desc = $json_quote->{'longName'};
      my $price = $json_quote->{'price'};
      my $curr  = $json_quote->{'issuedCurrency'};
      my $date  = $json_quote->{'lastUpdate'};

      $curr =~ s/.*[(](.*)[)].*/$1/;
      $price =~ s/,//g;
      if ($curr eq "GBp") {
        $curr = "GBP";
        $price = $price / 100;
      }
      $date = $1 if $date =~ m|([0-9]{4}-[0-9]{2}-[0-9]{2})T.*|;

      $funds{$name, 'method'}   = 'bloomberg';
      $funds{$name, 'name'}     = $desc;
      $funds{$name, 'last'}     = $price;
      $funds{$name, 'currency'} = $curr;
      $funds{$name, 'symbol'}   = $name;

      $quoter->store_date(\%funds, $name, {isodate => $date});

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

Labels returned by this module include: name, last, currency, symbol, isodate

=head1 SEE ALSO

Finance::Quote

=cut
