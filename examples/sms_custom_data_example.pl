#!/usr/bin/env perl

use strict;
use warnings;
use 5.016;

use lib '../lib', 'lib';
use CCAI;
use CCAI::EnvLoader;
use JSON;

# Load environment variables from .env file
CCAI::EnvLoader->load();

# Example SMS usage with customData
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

    # Example 1: Send SMS with customData to multiple recipients
    print "Example 1: Sending SMS with customData to multiple recipients\n";
    print "=" x 60 . "\n";
    
    my @accounts = (
        {
            first_name => "John",
            last_name  => "Doe",
            phone      => "+14155551212",
            customData => {
                order_id => "ORD-12345"
            }
        }
    );

    my $response = $ccai->sms->send(
        \@accounts,
        "Hello \${first_name} \${last_name}, your order has been confirmed!",
        "Order Confirmation Campaign"
    );

    if ($response->{success}) {
        print "✓ SMS with customData sent successfully!\n";
        print "Campaign ID: " . ($response->{data}->{campaign_id} // 'N/A') . "\n";
        print "Messages sent: " . ($response->{data}->{messages_sent} // 'N/A') . "\n";
        print "\nCustom data will be included in webhook events for tracking.\n";
    } else {
        print "✗ Error sending SMS: " . $response->{error} . "\n";
    }

    print "\n";

    # Example 2: Send single SMS with customData
    print "Example 2: Sending single SMS with customData\n";
    print "=" x 60 . "\n";
    
    my $custom_data = {
        appointment_id => "APPT-789"
    };

    my $single_response = $ccai->sms->send_single(
        "Alice",
        "Johnson",
        "+14155551212",
        "Hi \${first_name}, this is a reminder about your appointment tomorrow.",
        "Appointment Reminder",
        undef,  # options
        $custom_data
    );

    if ($single_response->{success}) {
        print "✓ Single SMS with customData sent successfully!\n";
        print "Custom data included:\n";
        print JSON->new->pretty->encode($custom_data);
    } else {
        print "✗ Error sending single SMS: " . $single_response->{error} . "\n";
    }

    print "\n";

    # Example 3: Different types of customData
    print "Example 3: Various customData examples\n";
    print "=" x 60 . "\n";
    
    my @varied_accounts = (
        {
            first_name => "Bob",
            last_name  => "Wilson",
            phone      => "+14155551212",
            customData => {
                cart_id => "CART-456"
            }
        }
    );

    my $varied_response = $ccai->sms->send(
        \@varied_accounts,
        "Hi \${first_name}, we have an update for you!",
        "Multi-Purpose Notification Campaign"
    );

    if ($varied_response->{success}) {
        print "✓ SMS campaign with varied customData sent successfully!\n";
        print "Campaign ID: " . ($varied_response->{data}->{campaign_id} // 'N/A') . "\n";
        
        print "\nCustom data examples sent:\n";
        for my $i (0 .. $#varied_accounts) {
            my $account = $varied_accounts[$i];
            print "- " . $account->{first_name} . " " . $account->{last_name} . ": ";
            print "Contains " . scalar(keys %{$account->{customData}}) . " custom fields\n";
        }
    } else {
        print "✗ Error sending varied SMS campaign: " . $varied_response->{error} . "\n";
    }

    print "\n";
    print "=" x 60 . "\n";
    print "CustomData Usage Notes:\n";
    print "- customData is optional and can contain any key-value pairs\n";
    print "- Data will be included in webhook events for message tracking\n";
    print "- Useful for correlating messages with business processes\n";
    print "- Can include order IDs, customer info, transaction data, etc.\n";
    print "- Data is preserved exactly as sent in webhook notifications\n";
    print "=" x 60 . "\n";

    print "\nSMS customData examples completed!\n";
}

# Run the examples
main() unless caller;

1;
