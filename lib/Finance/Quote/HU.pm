#!/usr/bin/perl -w
#
# HU.pm
#
# Version 0.3 - Fixed BAMOSZ website scraping and download stocks
# directly from www.BET.hu
# This version based on ZA.pm module
#
# Zoltan Levardy <zoltan at levardy dot org> 2008, 2009
# Kristof Marussy <kris7topher at gmail dot com> 2014

package Finance::Quote::HU;

use strict;

use constant DEBUG => $ENV{DEBUG};
use if DEBUG, 'Smart::Comments';

use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;
use Encode;
use JSON;
use Web::Scraper;

# VERSION

my $BAMOSZ_MAINURL = "http://www.bamosz.hu/";
my $BAMOSZ_URL = $BAMOSZ_MAINURL . "alapoldal?isin=";

my $BSE_MAINURL = "http://www.bet.hu/";
my $BSE_URL = $BSE_MAINURL . '/oldalak/ceg_adatlap/$security/';

sub methods {
    return ( hufund  => \&bamosz,
             bamosz  => \&bamosz,
             hustock => \&bse,
             bse     => \&bse,
             bet     => \&bse,
             hu      => \&hu,
             hungary => \&hu
    );
}

sub labels {
    my @fundlabels =
        qw/symbol method source name currency isin date isodate price last/;
    my @stocklabels =
        qw/symbol method source currency isin date isodate price open close
           high low p_change last/;
    my @alllabels = ( @stocklabels, "name" );
    return ( hufund  => \@fundlabels,
             bamosz  => \@fundlabels,
             hustock => \@stocklabels,
             bse     => \@stocklabels,
             bet     => \@stocklabels,
             hu      => \@alllabels,
             hungary => \@alllabels
    );
}

sub hu {
    my $quoter  = shift;
    my @symbols = @_;
    my %info;

    for my $symbol (@symbols) {
        my %bse_info = bse( $quoter, $symbol );
        if ( $bse_info{ $symbol, "success" } ) {
            %info = ( %info, %bse_info );
            next;
        }

        my %bamosz_info = bamosz( $quoter, $symbol );
        if ( $bamosz_info{ $symbol, "success" } ) {
            %info = ( %info, %bamosz_info );
            next;
        }

        $info{ $symbol, "success" }  = 0;
        $info{ $symbol, "errormsg" } = "Fetch from bse or bamosz failed";
    }

    return wantarray() ? %info : \%info;
}

sub bse {
  my $quoter  = shift;
  my @symbols = @_;
  my %info;

  my $ua = $quoter->user_agent;

  for my $symbol (@symbols) {
    eval {
      my $url      = $BSE_URL . $symbol;
      my $response = $ua->request(GET $url);

      ### bse response : $response->content

      die "Request error" unless $response->is_success;
      die "Failed to find JSON data" unless $response->content =~ m|window[.]dataSourceResults=({.+})</script>|;

      my $json = decode_json $1;

      ### json : $json

      ### keys : keys %{$json}
      my @profile_key = grep {/CompanyProfileDataSource;table=left/} keys %{$json};
      die "Failed to process JSON" unless @profile_key == 1;

      my $profile = $json->{$profile_key[0]};

      ### profile : $profile

      foreach my $term (@{$profile}) {
        $info{$symbol, "close"} = hu_decimal($term->{value}) if $term->{title} eq "El\x{151}z\x{151} z\x{e1}r\x{f3}\x{e1}r";
        $info{$symbol, "high"}  = hu_decimal($term->{value}) if $term->{title} eq "Napi maximum"; 
        $info{$symbol, "low"}   = hu_decimal($term->{value}) if $term->{title} eq "Napi minimum"; 
      }

      my @trade_key = grep {/CompanyProfileDataSource;table=trades/} keys %{$json};
      die "Failed to process JSON" unless @trade_key == 1;

      my $trade = $json->{$trade_key[0]};

      $info{$symbol, "last"} = hu_decimal($trade->[0]->{price});

      my $processor = scraper {
        process '//*[@id="cp_tab_content_2"]/div[3]/div[3]/table/tbody/tr[1]/td[2]/span', 'ticker'   => 'TEXT';
        process '//*[@id="cp_tab_content_2"]/div[3]/div[3]/table/tbody/tr[2]/td[2]/span', 'isin'     => 'TEXT';
        process '//*[@id="cp_tab_content_2"]/div[3]/div[3]/table/tbody/tr[4]/td[2]/span', 'currency' => 'TEXT';
        process '//*[@id="cp_tab_content_2"]/div[1]/div/div/div[2]/div/div[2]/span[2]', 'date'       => 'TEXT';
      };

      my $data = $processor->scrape($response);

      ### data : $data

      $info{ $symbol, "symbol" }   = $data->{ticker};
      $info{ $symbol, "isin" }     = $data->{isin};
      $info{ $symbol, "currency" } = $data->{currency};
      
      $quoter->store_date(\%info, $symbol, {isodate => $data->{date}});

      $info{ $symbol, "method" }  = "bse";
      $info{ $symbol, "source" }  = $BSE_MAINURL;
      $info{ $symbol, "success" } = 1;
    };

    if ($@) {
      ### bse error : $@
      $info{ $symbol, "method"}   = "bse";
      $info{ $symbol, "errormsg"} = $@;
      $info{ $symbol, "success"}  = 0;
    }
  }

  return wantarray() ? %info : \%info;
}

sub bamosz {
    my $quoter  = shift;
    my @symbols = @_;
    my %info;

    my $ua = $quoter->user_agent;

    for my $symbol (@symbols) {
        $info{ $symbol, "method" }  = "bamosz";
        $info{ $symbol, "source" }  = $BAMOSZ_MAINURL;
        $info{ $symbol, "success" } = 0;

        my $url      = $BAMOSZ_URL . $symbol;
        my $response = $ua->request( GET $url);

        ### bamosz response : $response

        unless ( $response->is_success ) {
            $info{ $symbol, "errormsg" } = "Request error";
            next;
        }

        my $te = HTML::TableExtract->new( attribs => { class => "dataTable" } );
        $te->parse( decode_utf8( $response->content ) );
        unless ( $te->first_table_found ) {
            $info{ $symbol, "errormsg" } = "No dataTable found";
            next;
        }

        my $ts = $te->table( 0, 0 );
        $info{ $symbol, "name" } = $ts->cell( 0, 1 );
        my $isin = $ts->cell( 2, 1 );
        $info{ $symbol, "symbol" }   = $isin;
        $info{ $symbol, "isin" }     = $isin;
        $info{ $symbol, "currency" } = $ts->cell( 3, 1 );
        my $price = hu_decimal( $ts->cell( 5, 1 ) );
        $info{ $symbol, "price" } = $price;
        $info{ $symbol, "last" }  = $price;
        my $date = $ts->cell( 6, 1 );
        $quoter->store_date( \%info, $symbol, { isodate => $date } );

        $info{ $symbol, "success" } = 1;
    }

    return wantarray() ? %info : \%info;
}

sub trim {
    my $s = shift;
    if ($s) {
        $s =~ s/^\s+//;
        $s =~ s/\s+$//;
        return $s;
    }
    else {
        return '';
    }
}

sub hu_decimal {
    my $s = shift;
    if ($s) {
        $s =~ s/[^\d,-]//g;
        $s =~ s/,/./;
        return $s;
    }
    else {
        return '';
    }
}

1;

=head1 NAME

Finance::Quote::HU - Obtain Hungarian Securities from www.bet.hu
and www.bamosz.hu

=head1 SYNOPSIS

    use Finance::Quote;
    $q = Finance::Quote->new;
    # Don't know anything about failover yet...

=head1 DESCRIPTION

This module obtains information about Hungarian Securities. Share fetched from
www.bet.hu, while mutual funds retrieved from www.bamosz.hu. Stocks are
searched by ticker while mutual funds may only searched by ISIN.

=head1 LABELS RETURNED

Information available may include the following labels:

method source name symbol currency date last price low high open close
p_change

=head1 SEE ALSO

Budapest Stock Exchange (BET) website - http://www.bet.hu
BAMOSZ website - http://www.bamosz.hu/

Finance::Quote

=cut
