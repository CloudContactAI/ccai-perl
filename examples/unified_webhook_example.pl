#!/usr/bin/env perl

use strict;
use warnings;
use 5.016;

use lib '../lib';
use lib 'lib';
use CCAI;

# Example webhook payloads for different event types
my @example_payloads = (
    # message.sent
    q({
        "eventType": "message.sent",
        "data": {
            "SmsSid": 12345,
            "MessageStatus": "DELIVERED",
            "To": "+1234567890",
            "Message": "Hello! Your order #12345 has been shipped.",
            "CustomData": "order_id:12345,customer_type:premium",
            "ClientExternalId": "customer_abc123",
            "CampaignId": 67890,
            "CampaignTitle": "Order Notifications",
            "Segments": 2,
            "TotalPrice": 0.02
        }
    }),
    
    # message.incoming
    q({
        "eventType": "message.incoming",
        "data": {
            "SmsSid": 0,
            "MessageStatus": "RECEIVED",
            "To": "+0987654321",
            "Message": "Yes, I'm interested in learning more!",
            "CustomData": "",
            "ClientExternalId": "customer_abc123",
            "CampaignId": 67890,
            "CampaignTitle": "Lead Generation Campaign",
            "From": "+1234567890"
        }
    }),
    
    # message.excluded
    q({
        "eventType": "message.excluded",
        "data": {
            "SmsSid": 0,
            "MessageStatus": "EXCLUDED",
            "To": "+1234567890",
            "Message": "Hi {{name}}, check out our new products!",
            "CustomData": "lead_source:website,segment:new_users",
            "ClientExternalId": "customer_xyz789",
            "CampaignId": 67890,
            "CampaignTitle": "Product Launch Campaign",
            "ExcludedReason": "Duplicate phone number in campaign"
        }
    }),
    
    # message.error.carrier
    q({
        "eventType": "message.error.carrier",
        "data": {
            "SmsSid": 12345,
            "MessageStatus": "FAILED",
            "To": "+1234567890",
            "Message": "Your verification code is: 123456",
            "CustomData": "verification_attempt:1",
            "ClientExternalId": "user_def456",
            "CampaignId": 0,
            "CampaignTitle": "",
            "ErrorCode": "30008",
            "ErrorMessage": "Unknown destination handset",
            "ErrorType": "carrier"
        }
    }),
    
    # message.error.cloudcontact
    q({
        "eventType": "message.error.cloudcontact",
        "data": {
            "SmsSid": 12345,
            "MessageStatus": "FAILED",
            "To": "+1234567890",
            "Message": "Welcome to our service!",
            "CustomData": "signup_source:landing_page",
            "ClientExternalId": "new_user_ghi789",
            "CampaignId": 67890,
            "CampaignTitle": "Welcome Series",
            "ErrorCode": "CCAI-001",
            "ErrorMessage": "Insufficient account balance",
            "ErrorType": "cloudcontact"
        }
    })
);

# Create CCAI instance
my $ccai = CCAI->new({
    client_id => 'demo-client-id',
    api_key   => 'demo-api-key'
});

my $webhook = $ccai->webhook;

print "=== Unified Webhook Event Handler Demo ===\n\n";

# Process each example payload with the unified handler
for my $i (0..$#example_payloads) {
    my $payload = $example_payloads[$i];
    
    print "Processing event " . ($i + 1) . ":\n";
    
    my $success = $webhook->handle_event($payload, sub {
        my ($event_type, $data) = @_;
        
        print "🔔 Event Type: $event_type\n";
        
        if ($event_type eq 'message.sent') {
            print "✅ Message delivered to $data->{To}\n";
            print "   💰 Cost: \$$data->{TotalPrice}\n";
            print "   📊 Segments: $data->{Segments}\n";
            print "   📢 Campaign: $data->{CampaignTitle} (ID: $data->{CampaignId})\n";
            
        } elsif ($event_type eq 'message.incoming') {
            print "📨 Reply from $data->{From}: $data->{Message}\n";
            print "   📢 Original Campaign: $data->{CampaignTitle}\n";
            
        } elsif ($event_type eq 'message.excluded') {
            print "⚠️  Message excluded: $data->{ExcludedReason}\n";
            print "   📞 Target: $data->{To}\n";
            print "   📢 Campaign: $data->{CampaignTitle}\n";
            
        } elsif ($event_type eq 'message.error.carrier') {
            print "❌ Carrier error $data->{ErrorCode}: $data->{ErrorMessage}\n";
            print "   📞 Target: $data->{To}\n";
            print "   🏢 Error Type: $data->{ErrorType}\n";
            
        } elsif ($event_type eq 'message.error.cloudcontact') {
            print "🚨 System error $data->{ErrorCode}: $data->{ErrorMessage}\n";
            print "   📞 Target: $data->{To}\n";
            print "   📢 Campaign: $data->{CampaignTitle}\n";
        }
        
        # Show custom data if present
        if ($data->{CustomData} && $data->{CustomData} ne '') {
            print "   📋 Custom Data: $data->{CustomData}\n";
        }
    });
    
    if ($success) {
        print "   ✅ Event processed successfully\n";
    } else {
        print "   ❌ Failed to process event\n";
    }
    
    print "\n" . ("-" x 50) . "\n\n";
}

print "Demo completed!\n";
