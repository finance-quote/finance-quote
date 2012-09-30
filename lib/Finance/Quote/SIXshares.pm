# SIX Swiss Exchange - Shares
# (c) 2011 Stephan Walter <stephan@walter.name>
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.

package Finance::Quote::SIXshares;

use HTTP::Request::Common;

my $url = 'http://www.six-swiss-exchange.com/shares/security_info_en.html?id=';

sub methods { return ( sixshares => \&sixshares ); }

sub labels {
    return ( sixshares => [qw/name date time price last currency p_change/] );
}

sub sixshares {
    my $quoter  = shift;
    my @symbols = @_;
    return unless @symbols;
    my ( $ua, $reply, %q );

    foreach my $symbol (@symbols) {
        $ua = $quoter->user_agent;
        $q{ $symbol, 'success' } = 0;
        $q{ $symbol, 'name' }    = $symbol;
        $q{ $symbol, 'symbol' }  = $symbol;
        $reply = $ua->request( GET( $url . $symbol ) );
        if ( !$reply->is_success ) {
            $q{ $symbol, 'errormsg' } = 'HTTP failure';
        }
        else {
            if ( $reply->content
                =~ />([A-Z]{3})&nbsp;<\/td><td.+?id="mop_ClosingPrice".+?>([0-9.]+)<\/td>/
                )
            {
                $q{ $symbol, 'currency' } = $1;
                $q{ $symbol, 'last' }     = $2;
                $q{ $symbol, 'success' }  = 1;
            }
            if ( $reply->content
                =~ /<td.+?id="mop_LastDate".+?>([0-3][0-9]\.[01][0-9]\.[0-9]{4})<\/td>/
                )
            {
                $quoter->store_date( \%q, $symbol, { eurodate => $1 } );
            }
            if ( $reply->content
                =~ /<td.+?id="mop_LastTime".+?>([0-2][0-9]:[0-5][0-9]:[0-5][0-9])<\/td>/
                )
            {
                $q{ $symbol, 'time' } = $1;
            }
            if ( $reply->content
                 =~ /<td.+?id="mop_ClosingDelta".+?>(-?[0-9.]+)%<\/td>/ )
            {
                $q{ $symbol, 'p_change' } = $1;
            }
        }
    }
    return wantarray ? %q : \%q;
}
