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
        client_id => 'YOUR_CLIENT_ID',
        api_key   => 'YOUR_API_KEY'
    });

    # Define recipients
    my @accounts = (
        {
            firstName => "John",
            lastName  => "Doe",
            phone      => "+14155551212"
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
        "Hello \${firstName}, check out this Perl image!",
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