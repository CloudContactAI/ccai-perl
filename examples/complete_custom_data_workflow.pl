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

# Complete CustomData Workflow Example
# This example demonstrates the full lifecycle of customData from sending SMS to handling webhooks

sub main {
    print "CCAI Perl v1.4.0 - Complete CustomData Workflow\n";
    print "=" x 60 . "\n";

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

    # Step 1: Send SMS messages with different types of customData
    print "Step 1: Sending SMS messages with customData\n";
    print "-" x 40 . "\n";

    # E-commerce order notifications
    my @ecommerce_accounts = (
        {
            firstName => "John",
            lastName  => "Doe",
            phone      => "+14155551212",
            customData => {
                order_id => "ORD-2025-001",
                customer_id => "CUST-12345",
                order_total => 299.99,
                items => [
                    { name => "Wireless Headphones", price => 199.99 },
                    { name => "Phone Case", price => 29.99 },
                    { name => "Screen Protector", price => 19.99 }
                ],
                shipping_method => "express",
                estimated_delivery => "2025-08-28",
                customer_tier => "gold",
                payment_method => "credit_card",
                promo_code => "SAVE20"
            }
        },
        {
            firstName => "Sarah",
            lastName  => "Johnson",
            phone      => "+14155551213",
            customData => {
                order_id => "ORD-2025-002",
                customer_id => "CUST-67890",
                order_total => 149.50,
                items => [
                    { name => "Bluetooth Speaker", price => 149.50 }
                ],
                shipping_method => "standard",
                estimated_delivery => "2025-08-30",
                customer_tier => "silver",
                payment_method => "paypal",
                is_gift => 1,
                gift_message => "Happy Birthday!"
            }
        }
    );

    my $ecommerce_response = $ccai->sms->send(
        \@ecommerce_accounts,
        "Hi \${firstName}! Your order has been confirmed and will arrive by your estimated delivery date. Thank you for shopping with us!",
        "E-commerce Order Confirmations"
    );

    if ($ecommerce_response->{success}) {
        print "✅ E-commerce notifications sent successfully!\n";
        print "   Campaign ID: " . ($ecommerce_response->{data}->{campaign_id} // 'N/A') . "\n";
    } else {
        print "❌ E-commerce notifications failed: " . $ecommerce_response->{error} . "\n";
    }

    # Healthcare appointment reminders
    my @healthcare_accounts = (
        {
            firstName => "Michael",
            lastName  => "Brown",
            phone      => "+14155551214",
            customData => {
                appointment_id => "APPT-2025-100",
                patient_id => "PAT-54321",
                provider => "Dr. Emily Wilson",
                specialty => "Cardiology",
                appointment_date => "2025-08-28",
                appointment_time => "14:30",
                location => "Downtown Medical Center",
                room => "Suite 205",
                insurance_verified => 1,
                copay_amount => 25.00,
                reminder_type => "24hr",
                special_instructions => "Please arrive 15 minutes early"
            }
        }
    );

    my $healthcare_response = $ccai->sms->send(
        \@healthcare_accounts,
        "Hi \${firstName}, this is a reminder about your appointment tomorrow. Please arrive 15 minutes early.",
        "Healthcare Appointment Reminders"
    );

    if ($healthcare_response->{success}) {
        print "✅ Healthcare reminders sent successfully!\n";
        print "   Campaign ID: " . ($healthcare_response->{data}->{campaign_id} // 'N/A') . "\n";
    } else {
        print "❌ Healthcare reminders failed: " . $healthcare_response->{error} . "\n";
    }

    # Service notifications
    my $service_response = $ccai->sms->send_single(
        "Lisa",
        "Davis",
        "+14155551215",
        "Hi \${firstName}, your service appointment is scheduled for tomorrow between 2-4 PM.",
        "Service Appointment Notification",
        undef,  # options
        {       # customData
            service_request_id => "SR-2025-500",
            customer_id => "CUST-98765",
            service_type => "HVAC Maintenance",
            technician => "Mike Rodriguez",
            technician_phone => "+14155559999",
            service_window => "14:00-16:00",
            estimated_duration => "2 hours",
            service_address => "123 Oak Street, San Francisco, CA",
            priority => "routine",
            equipment => ["furnace", "air_conditioning"],
            last_service_date => "2024-08-27",
            warranty_status => "active"
        }
    );

    if ($service_response->{success}) {
        print "✅ Service notification sent successfully!\n";
    } else {
        print "❌ Service notification failed: " . $service_response->{error} . "\n";
    }

    print "\n";

    # Step 2: Demonstrate webhook event handling
    print "Step 2: Webhook Event Handling with CustomData\n";
    print "-" x 40 . "\n";

    # Simulate various webhook events that would be received
    my @webhook_events = (
        {
            type => "message.sent",
            id => "msg_001",
            to => "+14155551212",
            from => "+14155559999",
            message => "Hi John! Your order has been confirmed...",
            timestamp => "2025-08-27T00:31:51.982Z",
            campaign_id => "camp_ecommerce_001",
            customData => $ecommerce_accounts[0]->{customData}
        },
        {
            type => "message.delivered",
            id => "msg_002",
            to => "+14155551214",
            from => "+14155559999",
            message => "Hi Michael, this is a reminder about your appointment...",
            timestamp => "2025-08-27T00:32:15.123Z",
            campaign_id => "camp_healthcare_001",
            customData => $healthcare_accounts[0]->{customData}
        },
        {
            type => "message.failed",
            id => "msg_003",
            to => "+14155551213",
            from => "+14155559999",
            message => "Hi Sarah! Your order has been confirmed...",
            timestamp => "2025-08-27T00:32:45.456Z",
            campaign_id => "camp_ecommerce_001",
            error => "Phone number unreachable",
            customData => $ecommerce_accounts[1]->{customData}
        },
        {
            type => "message.received",
            id => "msg_004",
            from => "+14155551215",
            to => "+14155559999",
            message => "What time exactly?",
            timestamp => "2025-08-27T00:33:30.789Z",
            customData => {
                # This would be from the original outbound message
                service_request_id => "SR-2025-500",
                customer_id => "CUST-98765",
                service_type => "HVAC Maintenance"
            }
        }
    );

    # Process each webhook event
    foreach my $event_data (@webhook_events) {
        my $json = JSON->new->encode($event_data);
        process_webhook_with_custom_data($ccai, $json);
    }

    print "\n";
    print "=" x 60 . "\n";
    print "CustomData Workflow Summary:\n";
    print "- ✅ SMS messages sent with rich customData\n";
    print "- ✅ Different business contexts (e-commerce, healthcare, service)\n";
    print "- ✅ Webhook events processed with customData correlation\n";
    print "- ✅ Business logic triggered based on customData content\n";
    print "- ✅ Error handling with context-aware fallback strategies\n";
    print "=" x 60 . "\n";
}

# Webhook processing function with customData handling
sub process_webhook_with_custom_data {
    my ($ccai, $event_json) = @_;
    
    # Parse the webhook event
    my $event = $ccai->webhook->parse_event($event_json);
    return unless $event;
    
    print "📨 Processing webhook: $event->{type} (ID: $event->{id})\n";
    
    if ($event->{customData}) {
        my $custom = $event->{customData};
        
        # E-commerce order processing
        if ($custom->{order_id}) {
            print "   🛒 E-commerce Order: $custom->{order_id}\n";
            print "   💰 Order Total: \$" . ($custom->{order_total} // 'N/A') . "\n";
            print "   👤 Customer Tier: " . ($custom->{customer_tier} // 'standard') . "\n";
            
            if ($event->{type} eq 'message.delivered') {
                print "   ✅ Order confirmation delivered successfully\n";
                # Business logic: Update order status
                # update_order_status($custom->{order_id}, 'notification_sent');
                
                # Special handling for premium customers
                if ($custom->{customer_tier} eq 'gold') {
                    print "   🌟 Gold customer - adding bonus points\n";
                    # add_loyalty_points($custom->{customer_id}, 100);
                }
                
            } elsif ($event->{type} eq 'message.failed') {
                print "   ❌ Order confirmation failed - implementing fallback\n";
                # Business logic: Send email instead
                # send_order_confirmation_email($custom->{order_id});
                
                # If it's a gift order, notify the sender
                if ($custom->{is_gift}) {
                    print "   🎁 Gift order - notifying sender about delivery issue\n";
                    # notify_gift_sender($custom->{order_id});
                }
            }
        }
        
        # Healthcare appointment processing
        if ($custom->{appointment_id}) {
            print "   🏥 Healthcare Appointment: $custom->{appointment_id}\n";
            print "   👨‍⚕️ Provider: " . ($custom->{provider} // 'N/A') . "\n";
            print "   📅 Date: " . ($custom->{appointment_date} // 'N/A') . "\n";
            
            if ($event->{type} eq 'message.delivered') {
                print "   ✅ Appointment reminder delivered\n";
                # Business logic: Mark reminder as sent
                # update_appointment_reminder_status($custom->{appointment_id}, 'sent');
                
                # Check if insurance is verified
                if (!$custom->{insurance_verified}) {
                    print "   ⚠️  Insurance not verified - sending follow-up\n";
                    # send_insurance_verification_reminder($custom->{patient_id});
                }
            }
        }
        
        # Service request processing
        if ($custom->{service_request_id}) {
            print "   🔧 Service Request: $custom->{service_request_id}\n";
            print "   👷 Technician: " . ($custom->{technician} // 'N/A') . "\n";
            print "   🏠 Service Type: " . ($custom->{service_type} // 'N/A') . "\n";
            
            if ($event->{type} eq 'message.received') {
                print "   💬 Customer replied - routing to technician\n";
                # Business logic: Forward customer question to technician
                # forward_to_technician($custom->{service_request_id}, $event->{message});
                
                # If high priority, escalate immediately
                if ($custom->{priority} eq 'urgent') {
                    print "   🚨 Urgent service - escalating immediately\n";
                    # escalate_service_request($custom->{service_request_id});
                }
            }
        }
        
        # Analytics and tracking
        print "   📊 Logging event for analytics\n";
        # log_message_event($event, $custom);
        
    } else {
        print "   ℹ️  No custom data in this event\n";
    }
    
    print "\n";
}

# Run the complete workflow
main() unless caller;

1;
