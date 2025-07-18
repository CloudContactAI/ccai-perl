#!/usr/bin/env perl

use strict;
use warnings;
use 5.016;

use lib '../lib', 'lib';
use CCAI;

# Example MMS usage
sub main {
    # Initialize the client
    my $ccai = CCAI->new({
        client_id => 'YOUR-CLIENT-ID',
        api_key   => 'YOUR-API-KEY'
    });

    # Define recipients
    my @accounts = (
        {
            first_name => "John",
            last_name  => "Doe",
            phone      => "+15551234567"
        }
    );

    # Progress callback
    my $progress_callback = sub {
        my $status = shift;
        print "Progress: $status\n";
    };

    my $options = {
        timeout     => 60000,
        on_progress => $progress_callback
    };

    # Send MMS with image
    print "Sending MMS with imagePERL.jpg...\n";
    
    my $response = $ccai->mms->send_with_image(
        'imagePERL.jpg',
        'image/jpeg',
        \@accounts,
        "Hello \${first_name}, check out this Perl image!",
        "Perl MMS Test Campaign",
        $options
    );

    if ($response->{success}) {
        print "✓ MMS sent successfully!\n";
        print "Campaign ID: " . ($response->{data}->{campaign_id} // 'N/A') . "\n";
    } else {
        print "✗ Error sending MMS: " . $response->{error} . "\n";
    }
}

# Run the example
main() unless caller;

1;