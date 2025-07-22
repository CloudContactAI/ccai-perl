#!/usr/bin/env perl

use strict;
use warnings;
use 5.016;

use lib 'lib';
use CCAI;
use HTTP::Server::Simple::CGI;
use JSON;
use Digest::SHA qw(hmac_sha256_hex);
use Data::Dumper;

my $WEBHOOK_SECRET = "ccai-webhook-secret";  # Set this to match your webhook registration

# Create a simple HTTP server
package WebhookServer;
use base qw(HTTP::Server::Simple::CGI);

# Handle incoming requests
sub handle_request {
    my ($self, $cgi) = @_;
    
    # Only handle POST requests
    if ($cgi->request_method() eq 'POST') {
        # Read the request body
        my $json = "";
        while (my $line = <STDIN>) {
            $json .= $line;
        }
        
        # Get the signature from headers
        my $signature = $cgi->http('X-CCAI-Signature');
        
        print "HTTP/1.0 200 OK\r\n";
        print "Content-Type: application/json\r\n\r\n";
        print "{\"status\":\"received\"}\r\n";
        
        # Process the webhook
        process_webhook($json, $signature);
    } else {
        print "HTTP/1.0 200 OK\r\n";
        print "Content-Type: text/html\r\n\r\n";
        print "<html><body><h1>CCAI Webhook Receiver</h1><p>Ready to receive webhook events.</p></body></html>\r\n";
    }
}

# Process the webhook data
sub process_webhook {
    my ($json, $signature) = @_;
    
    print STDERR "\n===== WEBHOOK RECEIVED =====\n";
    
    # Initialize CCAI client for webhook verification
    my $ccai = CCAI->new({
        client_id => '2682',
        api_key   => 'eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJpbmZvQGFsbGNvZGUuY29tIiwiaXNzIjoiY2xvdWRjb250YWN0IiwibmJmIjoxNzE5NDQwMjM2LCJpYXQiOjE3MTk0NDAyMzYsInJvbGUiOiJVU0VSIiwiY2xpZW50SWQiOjI2ODIsImlkIjoyNzY0LCJ0eXBlIjoiQVBJX0tFWSIsImtleV9yYW5kb21faWQiOiI1MGRiOTUzZC1hMjUxLTRmZjMtODI5Yi01NjIyOGRhOGE1YTAifQ.PKVjXYHdjBMum9cTgLzFeY2KIb9b2tjawJ0WXalsb8Bckw1RuxeiYKS1bw5Cc36_Rfmivze0T7r-Zy0PVj2omDLq65io0zkBzIEJRNGDn3gx_AqmBrJ3yGnz9s0WTMr2-F1TFPUByzbj1eSOASIKeI7DGufTA5LDrRclVkz32Oo'
    });
    
    # Verify signature if provided
    if ($signature) {
        my $is_valid = $ccai->webhook->verify_signature($signature, $json, $WEBHOOK_SECRET);
        if ($is_valid) {
            print STDERR "✓ Signature verified\n";
        } else {
            print STDERR "✗ Invalid signature\n";
            print STDERR "  Received: $signature\n";
        }
    } else {
        print STDERR "No signature provided\n";
    }
    
    # Parse and display the JSON
    eval {
        my $event = $ccai->webhook->parse_event($json);
        if ($event) {
            print STDERR "Event Type: $event->{type}\n";
            print STDERR "From: $event->{from}\n" if $event->{from};
            print STDERR "To: $event->{to}\n" if $event->{to};
            print STDERR "Message: $event->{message}\n" if $event->{message};
            print STDERR "Full payload:\n";
            print STDERR Dumper($event);
        } else {
            print STDERR "Failed to parse event\n";
        }
    };
    if ($@) {
        print STDERR "Error parsing JSON: $@\n";
        print STDERR "Raw payload: $json\n";
    }
    
    print STDERR "============================\n";
}

# Create and run the server
my $server = WebhookServer->new(8080);
print "Starting webhook receiver on port 8080...\n";
print "Use ngrok to expose this server: ngrok http 8080\n";
print "Then update the webhook_example.pl script with your ngrok URL\n";
$server->run();