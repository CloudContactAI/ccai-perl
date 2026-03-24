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

# --demo mode: process example payloads locally without starting a server
if (grep { $_ eq '--demo' } @ARGV) {
    run_demo();
    exit 0;
}

# Start HTTP server
my $daemon = HTTP::Daemon->new(
    LocalPort => $port,
    ReuseAddr => 1
) or die "Cannot create HTTP daemon: $!";

print "🚀 Unified Webhook Server started on port $port\n";
print "📡 Listening for CloudContact webhook events...\n";
print "🔑 Using webhook secret: $webhook_secret\n";
print "🛑 Press Ctrl+C to stop\n\n";

while (my $connection = $daemon->accept) {
    while (my $request = $connection->get_request) {
        if ($request->method eq 'POST' && $request->uri->path eq '/webhook') {
            handle_webhook($connection, $request);
        } else {
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

    my $success = process_event($body);

    my $response;
    if ($success) {
        print "✅ Event processed successfully\n";
        $response = HTTP::Response->new(200);
        $response->content('{"status": "success"}');
    } else {
        print "❌ Failed to process event\n";
        $response = HTTP::Response->new(400);
        $response->content('{"status": "error", "message": "Invalid event format"}');
    }
    $response->header('Content-Type' => 'application/json');
    $connection->send_response($response);
    print "\n" . ("-" x 60) . "\n\n";
}

sub process_event {
    my ($body) = @_;

    return $webhook->handle_event($body, sub {
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
        } elsif ($event_type eq 'message.error.carrier') {
            print "❌ Carrier error $data->{ErrorCode}: $data->{ErrorMessage}\n";
            print "   📞 Target: $data->{To}\n";
        } elsif ($event_type eq 'message.error.cloudcontact') {
            print "🚨 System error $data->{ErrorCode}: $data->{ErrorMessage}\n";
            print "   📞 Target: $data->{To}\n";
        }

        if ($data->{CustomData} && $data->{CustomData} ne '') {
            print "   📋 Custom Data: $data->{CustomData}\n";
        }
        if ($data->{ClientExternalId}) {
            print "   🆔 External ID: $data->{ClientExternalId}\n";
        }
    });
}

sub run_demo {
    print "=== Unified Webhook Event Handler Demo ===\n\n";

    my @payloads = (
        q({"eventType":"message.sent","data":{"SmsSid":12345,"MessageStatus":"DELIVERED","To":"+1234567890","Message":"Hello! Your order #12345 has been shipped.","CustomData":"order_id:12345,customer_type:premium","ClientExternalId":"customer_abc123","CampaignId":67890,"CampaignTitle":"Order Notifications","Segments":2,"TotalPrice":0.02}}),
        q({"eventType":"message.incoming","data":{"SmsSid":0,"MessageStatus":"RECEIVED","To":"+0987654321","Message":"Yes, I'm interested!","CustomData":"","ClientExternalId":"customer_abc123","CampaignId":67890,"CampaignTitle":"Lead Generation","From":"+1234567890"}}),
        q({"eventType":"message.excluded","data":{"SmsSid":0,"MessageStatus":"EXCLUDED","To":"+1234567890","Message":"Check out our new products!","CustomData":"lead_source:website","ClientExternalId":"customer_xyz789","CampaignId":67890,"CampaignTitle":"Product Launch","ExcludedReason":"Duplicate phone number in campaign"}}),
        q({"eventType":"message.error.carrier","data":{"SmsSid":12345,"MessageStatus":"FAILED","To":"+1234567890","Message":"Your verification code is: 123456","CustomData":"verification_attempt:1","ClientExternalId":"user_def456","CampaignId":0,"CampaignTitle":"","ErrorCode":"30008","ErrorMessage":"Unknown destination handset","ErrorType":"carrier"}}),
        q({"eventType":"message.error.cloudcontact","data":{"SmsSid":12345,"MessageStatus":"FAILED","To":"+1234567890","Message":"Welcome to our service!","CustomData":"signup_source:landing_page","ClientExternalId":"new_user_ghi789","CampaignId":67890,"CampaignTitle":"Welcome Series","ErrorCode":"CCAI-001","ErrorMessage":"Insufficient account balance","ErrorType":"cloudcontact"}}),
    );

    for my $i (0..$#payloads) {
        print "Event " . ($i + 1) . ":\n";
        my $ok = process_event($payloads[$i]);
        print($ok ? "   ✅ Processed\n" : "   ❌ Failed\n");
        print "\n" . ("-" x 50) . "\n\n";
    }

    print "Demo completed!\n";
}
