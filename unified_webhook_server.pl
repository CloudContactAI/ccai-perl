#!/usr/bin/env perl

use strict;
use warnings;
use 5.016;

use lib 'lib';
use CCAI;
use HTTP::Daemon;
use HTTP::Status;

# Configuration
my $port = 3000;
my $webhook_secret = $ENV{WEBHOOK_SECRET} || 'your-webhook-secret';

# Create CCAI instance
my $ccai = CCAI->new({
    client_id => 'demo-client-id',
    api_key   => 'demo-api-key'
});

my $webhook = $ccai->webhook;

# Create HTTP server
my $daemon = HTTP::Daemon->new(
    LocalPort => $port,
    ReuseAddr => 1
) or die "Cannot create HTTP daemon: $!";

print "🚀 Unified Webhook Server started on port $port\n";
print "📡 Listening for CloudContact webhook events...\n";
print "🔑 Using webhook secret: $webhook_secret\n";
print "🛑 Press Ctrl+C to stop\n\n";

# Handle requests
while (my $connection = $daemon->accept) {
    while (my $request = $connection->get_request) {
        if ($request->method eq 'POST' && $request->uri->path eq '/webhook') {
            handle_webhook($connection, $request);
        } else {
            # Send 404 for other requests
            my $response = HTTP::Response->new(404);
            $response->content("Not Found");
            $connection->send_response($response);
        }
    }
    $connection->close;
    undef($connection);
}

sub handle_webhook {
    my ($connection, $request) = @_;
    
    my $body = $request->content;
    my $signature = $request->header('X-CCAI-Signature') || '';
    
    print "🔔 Received webhook event\n";
    print "⏰ Time: " . localtime() . "\n";
    
    # Verify signature if secret is provided
    if ($webhook_secret && $webhook_secret ne 'your-webhook-secret') {
        unless ($webhook->verify_signature($signature, $body, $webhook_secret)) {
            print "❌ Invalid signature - rejecting request\n\n";
            my $response = HTTP::Response->new(401);
            $response->content("Unauthorized");
            $connection->send_response($response);
            return;
        }
        print "✅ Signature verified\n";
    }
    
    # Process the webhook event with unified handler
    my $success = $webhook->handle_event($body, sub {
        my ($event_type, $data) = @_;
        
        print "📋 Event Type: $event_type\n";
        
        if ($event_type eq 'message.sent') {
            print "✅ Message delivered to $data->{To}\n";
            print "   💰 Cost: \$$data->{TotalPrice}\n" if $data->{TotalPrice};
            print "   📊 Segments: $data->{Segments}\n" if $data->{Segments};
            print "   📢 Campaign: $data->{CampaignTitle} (ID: $data->{CampaignId})\n" if $data->{CampaignTitle};
            
        } elsif ($event_type eq 'message.incoming') {
            print "📨 Reply from $data->{From}: $data->{Message}\n";
            print "   📢 Original Campaign: $data->{CampaignTitle}\n" if $data->{CampaignTitle};
            
        } elsif ($event_type eq 'message.excluded') {
            print "⚠️  Message excluded: $data->{ExcludedReason}\n";
            print "   📞 Target: $data->{To}\n";
            print "   📢 Campaign: $data->{CampaignTitle}\n" if $data->{CampaignTitle};
            
        } elsif ($event_type eq 'message.error.carrier') {
            print "❌ Carrier error $data->{ErrorCode}: $data->{ErrorMessage}\n";
            print "   📞 Target: $data->{To}\n";
            print "   🏢 Error Type: $data->{ErrorType}\n" if $data->{ErrorType};
            
        } elsif ($event_type eq 'message.error.cloudcontact') {
            print "🚨 System error $data->{ErrorCode}: $data->{ErrorMessage}\n";
            print "   📞 Target: $data->{To}\n";
            print "   📢 Campaign: $data->{CampaignTitle}\n" if $data->{CampaignTitle};
        }
        
        # Show custom data if present
        if ($data->{CustomData} && $data->{CustomData} ne '') {
            print "   📋 Custom Data: $data->{CustomData}\n";
        }
        
        # Show external ID if present
        if ($data->{ClientExternalId}) {
            print "   🆔 External ID: $data->{ClientExternalId}\n";
        }
    });
    
    # Send response
    my $response;
    if ($success) {
        print "✅ Event processed successfully\n";
        $response = HTTP::Response->new(200);
        $response->content('{"status": "success"}');
        $response->header('Content-Type' => 'application/json');
    } else {
        print "❌ Failed to process event\n";
        $response = HTTP::Response->new(400);
        $response->content('{"status": "error", "message": "Invalid event format"}');
        $response->header('Content-Type' => 'application/json');
    }
    
    $connection->send_response($response);
    print "\n" . ("-" x 60) . "\n\n";
}
