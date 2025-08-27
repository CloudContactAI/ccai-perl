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

# Example webhook handling with customData
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

    print "Webhook CustomData Handling Examples\n";
    print "=" x 50 . "\n";

    # Example webhook event JSON with customData
    my $webhook_event_json = JSON->new->encode({
        type => "message.sent",
        id => "msg_12345",
        to => "+14155551212",
        from => "+14155559999",
        message => "Hello John Doe, your order has been confirmed!",
        timestamp => "2025-08-27T00:31:51.982Z",
        campaign_id => "camp_789",
        customData => {
            order_id => "ORD-12345",
            customer_type => "premium",
            purchase_amount => 299.99,
            notification_preference => "sms",
            items => ["laptop", "wireless_mouse"],
            shipping_address => {
                street => "123 Main St",
                city => "San Francisco",
                state => "CA",
                zip => "94105"
            }
        }
    });

    # Example 1: Parse webhook event with customData
    print "Example 1: Parsing webhook event with customData\n";
    print "-" x 50 . "\n";
    
    my $event = $ccai->webhook->parse_event($webhook_event_json);
    
    if ($event) {
        print "✓ Event parsed successfully!\n";
        print "Event Type: $event->{type}\n";
        print "Message ID: $event->{id}\n";
        print "To: $event->{to}\n";
        print "Message: $event->{message}\n";
        print "Timestamp: $event->{timestamp}\n";
        
        if ($event->{customData}) {
            print "\nCustom Data Found:\n";
            print JSON->new->pretty->encode($event->{customData});
            
            # Access specific custom data fields
            print "Order ID: " . ($event->{customData}->{order_id} // 'N/A') . "\n";
            print "Customer Type: " . ($event->{customData}->{customer_type} // 'N/A') . "\n";
            print "Purchase Amount: \$" . ($event->{customData}->{purchase_amount} // 'N/A') . "\n";
        } else {
            print "\nNo custom data in this event.\n";
        }
    } else {
        print "✗ Failed to parse webhook event\n";
    }

    print "\n";

    # Example 2: Different event types with customData
    print "Example 2: Different event types with customData\n";
    print "-" x 50 . "\n";

    my @sample_events = (
        {
            type => "message.delivered",
            id => "msg_12346",
            to => "+14155551213",
            message => "Your appointment is confirmed for tomorrow at 2 PM.",
            timestamp => "2025-08-27T00:32:00.000Z",
            customData => {
                appointment_id => "APPT-789",
                service_type => "consultation",
                provider => "Dr. Johnson",
                location => "Downtown Office",
                reminder_sent => 1
            }
        },
        {
            type => "message.failed",
            id => "msg_12347",
            to => "+14155551214",
            message => "Your order #12345 has shipped!",
            timestamp => "2025-08-27T00:32:30.000Z",
            error => "Invalid phone number",
            customData => {
                order_id => "ORD-12347",
                tracking_number => "1Z999AA1234567890",
                carrier => "UPS",
                retry_count => 3
            }
        },
        {
            type => "message.received",
            id => "msg_12348",
            from => "+14155551215",
            to => "+14155559999",
            message => "STOP",
            timestamp => "2025-08-27T00:33:00.000Z",
            customData => {
                # Note: Received messages typically don't have customData
                # unless it's a reply to a message that had customData
                original_campaign_id => "camp_789",
                opt_out_reason => "user_request"
            }
        }
    );

    foreach my $sample_event (@sample_events) {
        my $json = JSON->new->encode($sample_event);
        my $parsed = $ccai->webhook->parse_event($json);
        
        if ($parsed) {
            print "\n📧 Event: $parsed->{type}\n";
            print "   ID: $parsed->{id}\n";
            
            if ($parsed->{customData}) {
                print "   Custom Data Keys: " . join(", ", keys %{$parsed->{customData}}) . "\n";
                
                # Handle different business logic based on customData
                if ($parsed->{customData}->{order_id}) {
                    print "   🛒 Order-related event: " . $parsed->{customData}->{order_id} . "\n";
                }
                if ($parsed->{customData}->{appointment_id}) {
                    print "   📅 Appointment-related event: " . $parsed->{customData}->{appointment_id} . "\n";
                }
                if ($parsed->{customData}->{retry_count}) {
                    print "   🔄 Retry count: " . $parsed->{customData}->{retry_count} . "\n";
                }
            } else {
                print "   No custom data\n";
            }
        }
    }

    print "\n";

    # Example 3: Business logic based on customData
    print "Example 3: Business logic based on customData\n";
    print "-" x 50 . "\n";

    sub handle_webhook_event {
        my ($event_json, $signature, $secret) = @_;
        
        # Verify signature (in production)
        # if (!$ccai->webhook->verify_signature($signature, $event_json, $secret)) {
        #     print "❌ Invalid webhook signature\n";
        #     return;
        # }
        
        my $event = $ccai->webhook->parse_event($event_json);
        return unless $event;
        
        print "Processing event: $event->{type}\n";
        
        if ($event->{customData}) {
            my $custom = $event->{customData};
            
            # Order-related processing
            if ($custom->{order_id}) {
                print "  📦 Processing order: $custom->{order_id}\n";
                
                if ($event->{type} eq 'message.delivered') {
                    print "  ✅ Order notification delivered successfully\n";
                    # Update order status in database
                    # update_order_notification_status($custom->{order_id}, 'delivered');
                } elsif ($event->{type} eq 'message.failed') {
                    print "  ❌ Order notification failed\n";
                    # Handle failed notification - maybe try email instead
                    # fallback_to_email_notification($custom->{order_id});
                }
            }
            
            # Appointment-related processing
            if ($custom->{appointment_id}) {
                print "  🏥 Processing appointment: $custom->{appointment_id}\n";
                
                if ($event->{type} eq 'message.delivered') {
                    print "  ✅ Appointment reminder delivered\n";
                    # Mark reminder as sent
                    # update_appointment_reminder_status($custom->{appointment_id}, 'sent');
                }
            }
            
            # Customer segmentation
            if ($custom->{customer_type}) {
                print "  👤 Customer type: $custom->{customer_type}\n";
                
                if ($custom->{customer_type} eq 'premium' && $event->{type} eq 'message.failed') {
                    print "  🎯 Premium customer - escalating failed notification\n";
                    # Special handling for premium customers
                    # escalate_premium_customer_notification($event);
                }
            }
            
            # Analytics and tracking
            if ($custom->{campaign_type} || $custom->{source}) {
                print "  📊 Tracking analytics data\n";
                # Send to analytics system
                # track_message_event($event, $custom);
            }
        }
        
        print "  Event processing complete\n\n";
    }

    # Simulate handling the events
    foreach my $sample_event (@sample_events) {
        my $json = JSON->new->encode($sample_event);
        handle_webhook_event($json, "dummy_signature", "dummy_secret");
    }

    print "=" x 50 . "\n";
    print "CustomData Webhook Handling Benefits:\n";
    print "- Correlate webhook events with business processes\n";
    print "- Implement different logic based on message context\n";
    print "- Track campaign performance and customer segments\n";
    print "- Handle failures with context-aware fallback strategies\n";
    print "- Maintain audit trails for compliance and analytics\n";
    print "=" x 50 . "\n";

    print "\nWebhook customData examples completed!\n";
}

# Run the examples
main() unless caller;

1;
