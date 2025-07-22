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
        client_id => '2682',
        api_key   => 'eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJpbmZvQGFsbGNvZGUuY29tIiwiaXNzIjoiY2xvdWRjb250YWN0IiwibmJmIjoxNzE5NDQwMjM2LCJpYXQiOjE3MTk0NDAyMzYsInJvbGUiOiJVU0VSIiwiY2xpZW50SWQiOjI2ODIsImlkIjoyNzY0LCJ0eXBlIjoiQVBJX0tFWSIsImtleV9yYW5kb21faWQiOiI1MGRiOTUzZC1hMjUxLTRmZjMtODI5Yi01NjIyOGRhOGE1YTAifQ.PKVjXYHdjBMum9cTgLzFeY2KIb9b2tjawJ0WXalsb8Bckw1RuxeiYKS1bw5Cc36_Rfmivze0T7r-Zy0PVj2omDLq65io0zkBzIEJRNGDn3gx_AqmBrJ3yGnz9s0WTMr2-F1TFPUByzbj1eSOASIKeI7DGufTA5LDrRclVkz32Oo'
    });

    # Define recipients
    my @accounts = (
        {
            first_name => "John",
            last_name  => "Doe",
            phone      => "+14156961732"
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