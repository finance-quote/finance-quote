package Finance::Quote::CMBChina;

use strict;
use warnings;
use HTTP::Request::Common;
use Date::Parse;
use Encode qw(decode);
use HTML::TreeBuilder::XPath;

# VERSION

our $CMBCHINA_URL = 'https://cmbchina.com/cfweb/personal/prodvalue.aspx';
our @LABELS = qw/date isodate open high low close volume last method currency/;

sub labels {
    return ( cmbchina => [@LABELS] );
}

sub methods {
    return ( cmbchina => \&cmbchina );
}

sub cmbchina {
    my $quoter = shift;
    my @symbols = @_;
    
    my %info;
    my $ua = $quoter->user_agent();
    
    foreach my $symbol (@symbols) {
        # Construct URL with the product code
        my $url = "$CMBCHINA_URL?comCod=000&PrdType=T0052&PrdCode=$symbol";
        
        # Send HTTP request
        my $response = $ua->request(GET $url);
        
        # Add debug output for URL and response
        print STDERR "Request URL: $url\n";
        print STDERR "Response status: " . $response->status_line . "\n";
        
        # Check if request was successful
        unless ($response->is_success) {
            $info{$symbol, 'success'} = 0;
            $info{$symbol, 'errormsg'} = "HTTP request failed: " . $response->status_line;
            next;
        }
        
        # Use decoded_content to automatically detect encoding
        my $html = $response->decoded_content();
        
        # Add debug output
        use Data::Dumper;
        warn "Decoded HTML: " . substr($html, 0, 500) . "..." if $ENV{DEBUG};
        
        # Parse HTML to extract table data using XPath
        my $tree = HTML::TreeBuilder::XPath->new;
        $tree->parse($html);
        
        # Extract required data using provided XPath expressions
        my $product_code = $tree->findvalue('//*[@id="cList"]//table//tr[2]/td[1]/text()');
        my $net_value = $tree->findvalue('//*[@id="cList"]//table//tr[2]/td[3]/text()');
        my $date = $tree->findvalue('//*[@id="cList"]//table//tr[2]/td[5]/text()');
        
        # Trim whitespace from extracted values
        $product_code =~ s/^\s+|\s+$//g if defined $product_code;
        $net_value =~ s/^\s+|\s+$//g if defined $net_value;
        $date =~ s/^\s+|\s+$//g if defined $date;
        
        # Add debug output for extracted values
        warn "Extracted product code: '$product_code'" if $ENV{DEBUG};
        warn "Extracted net value: '$net_value'" if $ENV{DEBUG};
        warn "Extracted date: '$date'" if $ENV{DEBUG};
        
        # Check if we found the target product
        unless ($product_code && $product_code eq $symbol) {
            $info{$symbol, 'success'} = 0;
            $info{$symbol, 'errormsg'} = "Product code mismatch or not found";
            next;
        }
            
            # Populate info hash
            $info{$symbol, 'success'} = 1;
            $info{$symbol, 'symbol'} = $product_code;
            $info{$symbol, 'last'} = $net_value;
            $info{$symbol, 'method'} = 'cmbchina';
            $info{$symbol, 'currency'} = 'CNY'; # Assuming Chinese Yuan
            
            # Parse and store date
            if ($date) {
                # Try to parse date in different formats
                my $epoch = str2time($date) || str2time("20" . substr($date, 0, 2) . "-" . substr($date, 2, 2) . "-" . substr($date, 4, 2));
                if ($epoch) {
                    $info{$symbol, 'isodate'} = scalar(gmtime($epoch))->ymd;
                }
            }
    }
    
    return wantarray() ? %info : \%info;
}

1;

__END__

=head1 NAME

Finance::Quote::CMBChina - Obtain fund values from 招商银行 (China Merchants Bank)

=head1 SYNOPSIS

    use Finance::Quote;
    
    $q = Finance::Quote->new('CMBChina');
    %info = $q->fetch('cmbchina', 'XY040208');

=head1 DESCRIPTION

This module fetches fund values from China Merchants Bank's website
(https://cmbchina.com). It specifically targets the product value page
for wealth management products.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::CMBChina:
symbol, last, p_change, method, isodate, currency.

=head1 CAVEATS

This module assumes that the HTML structure of the CMBChina website remains
stable. Changes to the website layout may cause this module to fail or
return incorrect data.

=cut