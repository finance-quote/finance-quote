package Finance::Quote::Bloomberg;

use strict;

use LWP::UserAgent;
use HTTP::Request::Common;
use HTTP::CookieJar::LWP ();
use HTML::TreeBuilder;
use Encode;

# VERSION

use vars qw($BLOOMBERG_URL);

our $BLOOMBERG_URL = 'https://www.bloomberg.com/quote/';
our $DISPLAY = 'Bloomberg';
our @LABELS = qw/method name last currency symbol isodate/;

sub methods { 
    return (
        bloomberg => {
            subroutine => \&bloomberg,
            display => $DISPLAY,
            labels => \@LABELS
        }
    );
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
      my $desc  = $tree->look_down(_tag=>'div', 'class'=>qr/SecurityName_extraLarge/)->as_text();
      my $price = $tree->look_down(_tag=>'div', 'class'=>qr/^sized-price SizedPrice_extraLarge/)->as_text();
      my $curr  = $tree->look_down(_tag=>'span', 'class'=>qr/^quotePageHeader_securityDetails/)->as_text();
      my $date  = $tree->look_down(_tag=>'span', 'class'=>qr/^marketStatus_exchangeDelay/)->right();

      $curr =~ s/.*[(](.*)[)].*/$1/;
      $price =~ s/,//g;
      if ($curr eq "GBp") {
        $curr = "GBP";
        $price = $price / 100;
      }
      $date = $1 . "20" . $2 if $date =~ m|([0-9]{1,2}/[0-9]{1,2}/)([0-9]{2})$|;
      $date = $1 if $date =~ m|([0-9]{1,2}/[0-9]{1,2}/[0-9]{4})|;

      $funds{$name, 'method'}   = 'bloomberg';
      $funds{$name, 'name'}     = $desc;
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

Labels returned by this module include: name, last, currency, symbol, isodate

=head1 SEE ALSO

Finance::Quote

=cut
