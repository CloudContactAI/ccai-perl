#!/usr/bin/env perl

use strict;
use warnings;
use 5.016;

use lib '../lib';
use CCAI;

# Comprehensive example showing all CCAI Perl client features
sub main {
    print "CCAI Perl Client - Comprehensive Example\n";
    print "=" x 50 . "\n\n";

    # Initialize the client
    print "Initializing CCAI client...\n";
    my $ccai = CCAI->new({
        client_id => 'YOUR-CLIENT-ID',
        api_key   => 'API-KEY-TOKEN',
        # base_url  => 'https://custom.api.url/api'  # Optional custom base URL
    });
    print "✓ CCAI client initialized\n\n";

    # Display client information
    print "Client Information:\n";
    print "- Client ID: " . $ccai->get_client_id() . "\n";
    print "- Base URL: " . $ccai->get_base_url() . "\n\n";

    # SMS Examples
    print "SMS EXAMPLES\n";
    print "-" x 20 . "\n";
    
    sms_examples($ccai);
    
    print "\n";
    
    # MMS Examples
    print "MMS EXAMPLES\n";
    print "-" x 20 . "\n";
    
    mms_examples($ccai);
    
    print "\nComprehensive example completed!\n";
}

sub sms_examples {
    my $ccai = shift;
    
    # Example 1: Basic SMS to multiple recipients
    print "1. Basic SMS to multiple recipients:\n";
    
    my @accounts = (
        {
            firstName => "John",
            lastName  => "Doe",
            phone      => "+15551234567"
        },
        {
            firstName => "Jane",
            lastName  => "Smith",
            phone      => "+15559876543"
        },
        {
            firstName => "Bob",
            lastName  => "Johnson",
            phone      => "+15555551234"
        }
    );

    my $response = $ccai->sms->send(
        \@accounts,
        "Hello \${firstName} \${lastName}! This is a test message from our Perl client. Your phone number ends in " . 
        substr($accounts[0]->{phone}, -4) . ".",
        "Perl Multi-Recipient Test"
    );

    display_response($response, "Multi-recipient SMS");

    # Example 2: Single SMS with progress tracking
    print "\n2. Single SMS with progress tracking:\n";
    
    my $progress_callback = sub {
        my $status = shift;
        print "   Progress: $status\n";
    };

    my $options = {
        timeout     => 30000,
        retries     => 3,
        on_progress => $progress_callback
    };

    my $single_response = $ccai->sms->send_single(
        "Alice",
        "Williams",
        "+15555559999",
        "Hi \${firstName}! This is a personalized message with progress tracking.",
        "Perl Single SMS with Progress",
        $options
    );

    display_response($single_response, "Single SMS with progress");

    # Example 3: Template variable demonstration
    print "\n3. Template variable demonstration:\n";
    
    my @template_accounts = (
        {
            firstNname => "Michael",
            lastName  => "Brown",
            phone      => "+15551111111"
        }
    );

    my $template_response = $ccai->sms->send(
        \@template_accounts,
        "Dear \${firstName} \${lastName},\n\n" .
        "Welcome to our service! Your account has been created successfully.\n\n" .
        "Best regards,\nThe Team",
        "Welcome Message Template"
    );

    display_response($template_response, "Template variable SMS");
}

sub mms_examples {
    my $ccai = shift;
    
    # Example 1: Get signed URL
    print "1. Getting signed URL for image upload:\n";
    
    my $signed_url_response = $ccai->mms->get_signed_url(
        'sample_image.jpg',
        'image/jpeg',
        'perl-client/demo',  # Custom base path
        1                    # Public file
    );

    display_response($signed_url_response, "Signed URL request");

    if ($signed_url_response->{success}) {
        print "   Signed URL: " . substr($signed_url_response->{data}->{signed_s3_url}, 0, 50) . "...\n";
        print "   File Key: " . $signed_url_response->{data}->{file_key} . "\n";
    }

    # Example 2: Complete MMS workflow (demonstration)
    print "\n2. Complete MMS workflow demonstration:\n";
    
    my $image_path = 'demo_image.jpg';  # This would be a real image path
    
    print "   Image path: $image_path\n";
    print "   Content type: image/jpeg\n";
    
    # Define recipients for MMS
    my @mms_accounts = ({
        firstName => 'Sarah',
        lastName  => 'Davis',
        phone      => '+15552222222'
    });

    # Progress callback for MMS
    my $mms_progress = sub {
        my $status = shift;
        print "   MMS Progress: $status\n";
    };

    my $mms_options = {
        timeout     => 120000,  # Longer timeout for MMS
        on_progress => $mms_progress
    };

    print "   Would send MMS with message: 'Hello Sarah, check out this image!'\n";
    print "   Campaign title: 'Perl MMS Demo'\n";
    
    # For demonstration, we show what the call would look like
    print "   Call would be:\n";
    print "   \$ccai->mms->send_with_image(\n";
    print "       '$image_path',\n";
    print "       'image/jpeg',\n";
    print "       \\\@mms_accounts,\n";
    print "       'Hello \\\${firstName}, check out this image!',\n";
    print "       'Perl MMS Demo',\n";
    print "       \$mms_options\n";
    print "   );\n";

    # Uncomment the following lines to actually send MMS (requires real image file):
    # my $mms_response = $ccai->mms->send_with_image(
    #     $image_path,
    #     'image/jpeg',
    #     \@mms_accounts,
    #     "Hello \${firstName}, check out this image!",
    #     "Perl MMS Demo",
    #     $mms_options
    # );
    # display_response($mms_response, "Complete MMS workflow");
}

sub display_response {
    my ($response, $operation) = @_;
    
    if ($response->{success}) {
        print "   ✓ $operation: SUCCESS\n";
        if ($response->{data}) {
            for my $key (sort keys %{$response->{data}}) {
                my $value = $response->{data}->{$key};
                # Truncate long values for display
                if (defined $value && length($value) > 50) {
                    $value = substr($value, 0, 47) . "...";
                }
                print "     $key: " . ($value // 'N/A') . "\n";
            }
        }
    } else {
        print "   ✗ $operation: FAILED\n";
        print "     Error: " . $response->{error} . "\n";
    }
}

# Run the comprehensive example
main() unless caller;

1;
