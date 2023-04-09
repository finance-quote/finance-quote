package Finance::Quote::Oslobors;

use strict;
use JSON qw( decode_json );
use HTTP::Request::Common;

# VERSION

use vars qw( $OSLOBORS_COMPONENTS_URL );

$OSLOBORS_COMPONENTS_URL = "https://www.oslobors.no/ob/servlets/components?type=table&source=feed.omff.FUNDS&view=REALTIME&columns=ITEM%2C+PRICECHANGEPCT%2C+PRICE%2C+DATE%2C+QUOTATIONCURRENCY&filter=ITEM_SECTOR%3D%3Ds";

sub methods { return (oslobors => \&oslobors); }

{
  my @labels = qw/date isodate method source currency price p_change/;
  sub labels { return (oslobors => \@labels); }
}

sub oslobors {
  my $quoter = shift;
  my @symbols = @_;
  my %funds;

  my $ua = $quoter->user_agent;

  my ($url, $reply, $data);

  foreach my $symbol (@symbols) {
    $url = $OSLOBORS_COMPONENTS_URL . $symbol;
    $reply = $ua->request(GET $url);
    unless($reply->is_success) {
      $funds{$symbol, "success"} = 0;
      $funds{$symbol, "errormsg"} = "HTTP request failed";
    } else {
      $data = JSON::decode_json($reply->content)->{"rows"}[0]{"values"};

      $quoter->store_date(\%funds, $symbol, { isodate => sprintf("%s-%s-%s", $data->{"DATE"} =~ /(\d\d\d\d)(\d\d)(\d\d)/)});
      $funds{$symbol, 'method'}   = 'oslobors';
      $funds{$symbol, 'currency'} = $data->{"QUOTATIONCURRENCY"};
      $funds{$symbol, 'success' } = 1;
      $funds{$symbol, 'price'   } = $data->{"PRICE"};
      $funds{$symbol, 'source'  } = 'Finance::Quote::Oslobors';
      $funds{$symbol, 'symbol'  } = $symbol;
      $funds{$symbol, 'p_change'} = $data->{"PRICECHANGEPCT"};
    }
  }

  return wantarray() ? %funds : \%funds;
}

1;

=head1 NAME

Finance::Quote::Oslobors - Obtain fund quotes from Oslo stock exchange

=head1 SYNOPSIS

    use Finance::Quote;
    $q = Finance::Quote->new;
    %fundinfo = $q->fetch("oslobors","FUND-TICKER.OSE");

=head1 DESCRIPTION

This module obtains information about mutual fund prices from
www.oslobors.no.

=head1 FUND TICKER SYMBOLS

The fund ticker symbols can be found by searching for the fund,
and visit its page. The symbol will be visible in the URL, for
instance OD-HORIA.OSE. The .OSE part is necessary.

The package does not understand Oslo stock symbols.

=head1 LABELS RETURNED

The module returns date, method, source, currency, price and p_change.
The prices are updated on bank days.

=head1 SEE ALSO

Finance::Quote

=cut
