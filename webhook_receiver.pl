#!/usr/bin/env perl

use strict;
use warnings;
use 5.016;

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
    
    # Verify signature if provided
    if ($signature) {
        my $computed = hmac_sha256_hex($json, $WEBHOOK_SECRET);
        if ($computed eq $signature) {
            print STDERR "✓ Signature verified\n";
        } else {
            print STDERR "✗ Invalid signature\n";
            print STDERR "  Received: $signature\n";
            print STDERR "  Computed: $computed\n";
        }
    } else {
        print STDERR "No signature provided\n";
    }
    
    # Parse and display the JSON
    eval {
        my $data = decode_json($json);
        print STDERR "Event Type: $data->{type}\n";
        print STDERR "From: $data->{from}\n" if $data->{from};
        print STDERR "To: $data->{to}\n" if $data->{to};
        print STDERR "Message: $data->{message}\n" if $data->{message};
        print STDERR "Full payload:\n";
        print STDERR Dumper($data);
    };
    if ($@) {
        print STDERR "Error parsing JSON: $@\n";
        print STDERR "Raw payload: $json\n";
    }
    
    print STDERR "============================\n";
}

# Start the server
my $server = WebhookServer->new(8080);
print "Starting webhook receiver on port 8080...\n";
print "Use ngrok to expose this server: ngrok http 8080\n";
$server->run();