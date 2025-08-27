#!/usr/bin/env perl

use strict;
use warnings;
use 5.016;

use lib '../lib', 'lib';
use CCAI;
use CCAI::EnvLoader;

# Load environment variables from .env file
CCAI::EnvLoader->load();

# Example SMS usage
sub main {
    # Get credentials from environment variables
    my ($client_id, $api_key);
    
    eval {
        ($client_id, $api_key) = CCAI::EnvLoader->get_ccai_credentials();
    };
    if ($@) {
        print "❌ Configuration Error:\n";
        print $@;
        print "\nPlease create a .env file with your CCAI credentials.\n";
        print "You can copy .env.example to .env and fill in your credentials.\n";
        return;
    }
    
    print "🔧 Using credentials from environment variables\n";
    print "Client ID: " . substr($client_id, 0, 8) . "...\n";
    print "API Key: " . substr($api_key, 0, 8) . "...\n\n";

    # Initialize the client
    my $ccai = CCAI->new({
        client_id => $client_id,
        api_key   => $api_key
    });

    # Example 1: Send SMS to multiple recipients
    print "Example 1: Sending SMS to multiple recipients\n";
    print "=" x 50 . "\n";
    
    my @accounts = (
        {
            first_name => "John",
            last_name  => "Doe",
            phone      => "+14155551212"
        },
    );

    my $response = $ccai->sms->send(
        \@accounts,
        "Hello \${first_name} \${last_name}, this is a test message from Perl!",
        "Perl SMS Test Campaign"
    );

    if ($response->{success}) {
        print "✓ SMS sent successfully!\n";
        print "Campaign ID: " . ($response->{data}->{campaign_id} // 'N/A') . "\n";
        print "Messages sent: " . ($response->{data}->{messages_sent} // 'N/A') . "\n";
    } else {
        print "✗ Error sending SMS: " . $response->{error} . "\n";
    }

    print "\n";

    # Example 2: Send SMS to a single recipient with progress tracking
    print "Example 2: Sending SMS to single recipient with progress tracking\n";
    print "=" x 50 . "\n";
    
    my $progress_callback = sub {
        my $status = shift;
        print "Progress: $status\n";
    };

    my $options = {
        timeout     => 30000,
        on_progress => $progress_callback
    };

    my $single_response = $ccai->sms->send_single(
        "Alice",
        "Johnson",
        "+14155551212",
        "Hi \${first_name}, this is a personalized message just for you!",
        "Single SMS Test",
        $options
    );

    if ($single_response->{success}) {
        print "✓ Single SMS sent successfully!\n";
        print "Response: " . ($single_response->{data}->{status} // 'N/A') . "\n";
    } else {
        print "✗ Error sending single SMS: " . $single_response->{error} . "\n";
    }

    print "\n";

    # Example 3: Error handling demonstration
    print "Example 3: Error handling demonstration\n";
    print "=" x 50 . "\n";
    
    # Try to send with invalid data
    my $error_response = $ccai->sms->send(
        [],  # Empty accounts array
        "This should fail",
        "Error Test"
    );

    if ($error_response->{success}) {
        print "✓ Unexpected success\n";
    } else {
        print "✓ Expected error caught: " . $error_response->{error} . "\n";
    }

    print "\nSMS examples completed!\n";
}

# Run the examples
main() unless caller;

1;
