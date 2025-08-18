#!/usr/bin/env perl

use strict;
use warnings;
use 5.016;

use lib '../lib', 'lib';
use CCAI;
use Data::Dumper;

# Create a CCAI client
my $ccai = CCAI->new({
    client_id => 'YOUR_CLIENT_ID',
    api_key   => 'YOUR_API_KEY'
});

# Choose which examples to run
my $run_register = 1;  # Set to 1 to register a new webhook
my $run_list = 0;      # Set to 1 to list existing webhooks (Note: API endpoint may not be available)
my $run_update = 0;    # Set to 1 to update a webhook
my $run_delete = 0;    # Set to 1 to delete a webhook
my $run_parse = 1;     # Set to 1 to test parsing a webhook event

# Example 1: Register a webhook (set $run_register = 1 to enable)
my $webhook_id;
if ($run_register) {
    $webhook_id = register_webhook($ccai);
}

# Example 2: List webhooks (set $run_list = 1 to enable)
if ($run_list) {
    my $webhooks = list_webhooks($ccai);
    # If we need a webhook ID for update/delete and didn't register one,
    # use the first one from the list
    if (!$webhook_id && $webhooks && @$webhooks > 0) {
        $webhook_id = $webhooks->[0]->{id};
        print "Using webhook ID $webhook_id for operations\n";
    }
}

# Example 3: Update a webhook (set $run_update = 1 to enable)
if ($run_update && $webhook_id) {
    update_webhook($ccai, $webhook_id);
}

# Example 4: Delete a webhook (set $run_delete = 1 to enable)
if ($run_delete && $webhook_id) {
    delete_webhook($ccai, $webhook_id);
}

# Example 5: Parse a webhook event (set $run_parse = 1 to enable)
if ($run_parse) {
    parse_webhook_event($ccai);
}

# Example 1: Register a webhook
sub register_webhook {
    my ($ccai) = @_;
    
    print "Registering a webhook...\n";
    
    # To get a webhook URL for testing:
    # 1. Go to https://webhook.site/ and copy your unique URL
    # 2. Or use ngrok: run 'ngrok http 8080' and copy the https URL
    
    # Use ngrok to expose your local webhook server
    # 1. Start the webhook server: perl simple_webhook_server.pl
    # 2. In another terminal, run: ngrok http 8080
    # 3. Copy the https URL provided by ngrok (e.g., https://abc123.ngrok.io)
    # 4. Replace the URL below with your ngrok URL
    my $config = {
        url => "https://66d8d4c45b5c.ngrok-free.app",  # Your current ngrok URL
        events => ["message.sent", "message.received"],
        secret => "ccai-webhook-secret"  # A secret key to verify webhook authenticity
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
        
        return $response->{data}; # Return webhooks for potential use
    } else {
        print "Failed to list webhooks: $response->{error}\n";
        return undef;
    }
    
    print "\n";
}

# Example 3: Update a webhook
sub update_webhook {
    my ($ccai, $webhook_id) = @_;
    
    print "\nUpdating webhook $webhook_id...\n";
    
    my $config = {
        url => "https://66d8d4c45b5c.ngrok-free.app",  # Your current ngrok URL
        events => ["message.sent"],  # Only subscribe to message.sent events
        secret => "ccai-webhook-secret"  # Same secret as registration
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
    print "This demonstrates how to process webhook events when they arrive at your server\n";
    print "You would typically use this in a webhook handler script that receives POST requests\n\n";
    
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
    "to": "+14155551212",
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
        my $secret = "ccai-webhook-secret";
        
        my $is_valid = $ccai->webhook->verify_signature($signature, $json, $secret);
        
        print "Signature valid: " . ($is_valid ? "Yes" : "No") . "\n";
    } else {
        print "Failed to parse webhook event\n";
    }
    
    print "\n";
}
