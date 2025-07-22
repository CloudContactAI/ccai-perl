#!/usr/bin/env perl

use strict;
use warnings;
use 5.016;

use lib '../lib';
use CCAI;
use Data::Dumper;

# Create a CCAI client
my $ccai = CCAI->new({
    client_id => 'YOUR-CLIENT-ID',  # Replace with your client ID
    api_key   => 'YOUR-API-KEY'     # Replace with your API key
});

# Example 1: Register a webhook
my $webhook_id = register_webhook($ccai);

if ($webhook_id) {
    # Example 2: List webhooks
    list_webhooks($ccai);
    
    # Example 3: Update a webhook
    update_webhook($ccai, $webhook_id);
    
    # Example 4: Delete a webhook
    delete_webhook($ccai, $webhook_id);
}

# Example 5: Parse a webhook event
parse_webhook_event($ccai);

# Example 1: Register a webhook
sub register_webhook {
    my ($ccai) = @_;
    
    print "Registering a webhook...\n";
    
    my $config = {
        url => "https://your-webhook-endpoint.com/webhook",  # Replace with your webhook endpoint
        events => ["message.sent", "message.received"],
        secret => "your-webhook-secret"  # Replace with your webhook secret
    };
    
    my $response = $ccai->webhook->register($config);
    
    if ($response->{success}) {
        print "Webhook registered successfully: ID=$response->{data}->{id}, URL=$response->{data}->{url}\n";
        print "Subscribed events:\n";
        
        foreach my $event (@{$response->{data}->{events}}) {
            print "- $event\n";
        }
        
        return $response->{data}->{id};
    } else {
        print "Failed to register webhook: $response->{error}\n";
        return undef;
    }
    
    print "\n";
}

# Example 2: List webhooks
sub list_webhooks {
    my ($ccai) = @_;
    
    print "\nListing webhooks...\n";
    
    my $response = $ccai->webhook->list();
    
    if ($response->{success}) {
        print "Found " . scalar(@{$response->{data}}) . " webhooks:\n";
        
        foreach my $webhook (@{$response->{data}}) {
            print "- ID=$webhook->{id}, URL=$webhook->{url}\n";
            print "  Subscribed events:\n";
            
            foreach my $event (@{$webhook->{events}}) {
                print "  - $event\n";
            }
        }
    } else {
        print "Failed to list webhooks: $response->{error}\n";
    }
    
    print "\n";
}

# Example 3: Update a webhook
sub update_webhook {
    my ($ccai, $webhook_id) = @_;
    
    print "\nUpdating webhook $webhook_id...\n";
    
    my $config = {
        url => "https://your-updated-endpoint.com/webhook",  # Replace with your updated webhook endpoint
        events => ["message.sent"],  # Only subscribe to message.sent events
        secret => "your-updated-secret"  # Replace with your updated webhook secret
    };
    
    my $response = $ccai->webhook->update($webhook_id, $config);
    
    if ($response->{success}) {
        print "Webhook updated successfully: ID=$response->{data}->{id}, URL=$response->{data}->{url}\n";
        print "Subscribed events:\n";
        
        foreach my $event (@{$response->{data}->{events}}) {
            print "- $event\n";
        }
    } else {
        print "Failed to update webhook: $response->{error}\n";
    }
    
    print "\n";
}

# Example 4: Delete a webhook
sub delete_webhook {
    my ($ccai, $webhook_id) = @_;
    
    print "\nDeleting webhook $webhook_id...\n";
    
    my $response = $ccai->webhook->delete($webhook_id);
    
    if ($response->{success}) {
        print "Webhook deleted successfully: $response->{data}->{message}\n";
    } else {
        print "Failed to delete webhook: $response->{error}\n";
    }
    
    print "\n";
}

# Example 5: Parse a webhook event
sub parse_webhook_event {
    my ($ccai) = @_;
    
    print "\nParsing a webhook event...\n";
    
    # Example webhook payload for a message.sent event
    my $json = <<'JSON';
{
    "type": "message.sent",
    "campaign": {
        "id": 12345,
        "title": "Test Campaign",
        "message": "Hello ${first_name}, this is a test message.",
        "senderPhone": "+15551234567",
        "createdAt": "2025-07-22T12:00:00Z",
        "runAt": "2025-07-22T12:01:00Z"
    },
    "from": "+15551234567",
    "to": "+15559876543",
    "message": "Hello John, this is a test message."
}
JSON
    
    my $event = $ccai->webhook->parse_event($json);
    
    if ($event) {
        print "Event type: $event->{type}\n";
        print "Campaign ID: $event->{campaign}->{id}\n";
        print "Campaign title: $event->{campaign}->{title}\n";
        print "From: $event->{from}\n";
        print "To: $event->{to}\n";
        print "Message: $event->{message}\n";
        
        # Example of verifying a webhook signature
        my $signature = "abcdef1234567890";  # This would come from the X-CCAI-Signature header
        my $secret = "your-webhook-secret";
        
        my $is_valid = $ccai->webhook->verify_signature($signature, $json, $secret);
        
        print "Signature valid: " . ($is_valid ? "Yes" : "No") . "\n";
    } else {
        print "Failed to parse webhook event\n";
    }
    
    print "\n";
}
