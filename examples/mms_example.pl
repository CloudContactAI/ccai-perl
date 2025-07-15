#!/usr/bin/env perl

use strict;
use warnings;
use 5.016;

use lib '../lib';
use CCAI;

# Example MMS usage
sub main {
    # Initialize the client
    my $ccai = CCAI->new({
        client_id => 'YOUR-CLIENT-ID',
        api_key   => 'API-KEY-TOKEN'
    });

    # Example 1: Complete MMS workflow with image
    print "Example 1: Complete MMS workflow with image\n";
    print "=" x 50 . "\n";
    
    # Define progress callback
    my $progress_callback = sub {
        my $status = shift;
        print "Progress: $status\n";
    };

    # Create options with progress tracking
    my $options = {
        timeout     => 60000,
        on_progress => $progress_callback
    };

    # Define recipients
    my @accounts = ({
        first_name => 'John',
        last_name  => 'Doe',
        phone      => '+15551234567'
    });

    # Note: You'll need to provide a real image path for this to work
    my $image_path = 'sample_image.jpg';  # Replace with actual image path
    my $content_type = 'image/jpeg';

    # Check if image exists (for demo purposes)
    unless (-f $image_path) {
        print "⚠ Image file not found: $image_path\n";
        print "Creating a placeholder for demonstration...\n";
        
        # For demo, we'll show what the call would look like
        print "Would call: \$ccai->mms->send_with_image(\n";
        print "    '$image_path',\n";
        print "    '$content_type',\n";
        print "    \\@accounts,\n";
        print "    \"Hello \\\${first_name}, check out this image!\",\n";
        print "    \"MMS Campaign Example\",\n";
        print "    \$options\n";
        print ");\n\n";
        
        # Skip actual sending for demo
        goto EXAMPLE2;
    }

    # Send MMS with image in one step
    my $response = $ccai->mms->send_with_image(
        $image_path,
        $content_type,
        \@accounts,
        "Hello \${first_name}, check out this image!",
        "MMS Campaign Example",
        $options
    );

    if ($response->{success}) {
        print "✓ MMS sent successfully!\n";
        print "Campaign ID: " . ($response->{data}->{campaign_id} // 'N/A') . "\n";
    } else {
        print "✗ Error sending MMS: " . $response->{error} . "\n";
    }

    print "\n";

    EXAMPLE2:
    # Example 2: Step-by-step MMS process
    print "Example 2: Step-by-step MMS process\n";
    print "=" x 50 . "\n";
    
    # Step 1: Get signed URL
    print "Step 1: Getting signed URL...\n";
    my $signed_url_response = $ccai->mms->get_signed_url(
        'test_image.jpg',
        'image/jpeg'
    );

    if ($signed_url_response->{success}) {
        print "✓ Signed URL obtained\n";
        print "File key: " . ($signed_url_response->{data}->{file_key} // 'N/A') . "\n";
        
        # For demo purposes, we won't actually upload or send
        print "Would proceed with upload and MMS sending...\n";
    } else {
        print "✗ Error getting signed URL: " . $signed_url_response->{error} . "\n";
    }

    print "\n";

    # Example 3: Error handling
    print "Example 3: Error handling demonstration\n";
    print "=" x 50 . "\n";
    
    # Try to get signed URL with missing parameters
    my $error_response = $ccai->mms->get_signed_url(
        '',  # Empty filename
        'image/jpeg'
    );

    if ($error_response->{success}) {
        print "✓ Unexpected success\n";
    } else {
        print "✓ Expected error caught: " . $error_response->{error} . "\n";
    }

    print "\nMMS examples completed!\n";
    print "\nNote: To test actual MMS sending, provide valid:\n";
    print "- Client ID and API key\n";
    print "- Image file path\n";
    print "- Valid phone numbers\n";
}

# Run the examples
main() unless caller;

1;
