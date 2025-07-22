#!/usr/bin/env perl

use strict;
use warnings;
use 5.016;

use IO::Socket::INET;

# Configuration
my $port = 3000;
my $server = IO::Socket::INET->new(
    LocalPort => $port,
    Type      => SOCK_STREAM,
    Reuse     => 1,
    Listen    => 10
) or die "Cannot create server on port $port: $!";

print "Simple webhook server running on port $port\n";
print "Run 'ngrok http $port' in another terminal\n";
print "Then use the ngrok URL in your webhook registration\n";

# Main server loop
while (my $client = $server->accept()) {
    # Read the HTTP request
    my $request = "";
    while (<$client>) {
        $request .= $_;
        last if $_ eq "\r\n";  # End of headers
    }
    
    # Check if it's a POST request
    if ($request =~ /^POST/i) {
        # Get content length
        my $content_length = 0;
        if ($request =~ /Content-Length: (\d+)/i) {
            $content_length = $1;
        }
        
        # Read the request body
        my $body = "";
        if ($content_length > 0) {
            read($client, $body, $content_length);
        }
        
        # Extract signature if present
        my $signature = "";
        if ($request =~ /X-CCAI-Signature: ([^\r\n]+)/i) {
            $signature = $1;
        }
        
        # Send response
        print $client "HTTP/1.1 200 OK\r\n";
        print $client "Content-Type: application/json\r\n";
        print $client "Connection: close\r\n";
        print $client "\r\n";
        print $client '{"status":"received"}';
        
        # Log the webhook
        print "\n===== WEBHOOK RECEIVED =====\n";
        print "Time: " . scalar(localtime) . "\n";
        print "Signature: " . ($signature || "none") . "\n";
        print "Body:\n$body\n";
        print "============================\n";
    } else {
        # Send HTML response for GET requests
        print $client "HTTP/1.1 200 OK\r\n";
        print $client "Content-Type: text/html\r\n";
        print $client "Connection: close\r\n";
        print $client "\r\n";
        print $client "<html><body><h1>CCAI Webhook Receiver</h1><p>Ready to receive webhook events.</p></body></html>";
    }
    
    close $client;
}

close $server;