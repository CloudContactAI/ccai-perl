#!/usr/bin/env perl

use strict;
use warnings;
use 5.016;

use lib 'lib';
use CCAI;
use CGI;
use JSON;

print "Content-type: application/json\n\n";

# This is a simple example of a webhook handler script
# You would typically deploy this on a web server that can run CGI scripts

# Initialize the CCAI client
my $ccai = CCAI->new({
    client_id => 'YOUR_CLIENT_ID',
    api_key   => 'YOUR_API_KEY'
});

# Create a CGI object
my $cgi = CGI->new;

# Get the webhook secret (should match what you set when registering the webhook)
my $webhook_secret = 'ccai-webhook-secret';

# Process the webhook
if ($cgi->request_method eq 'POST') {
    # Read the request body
    my $json = '';
    while (my $line = <STDIN>) {
        $json .= $line;
    }
    
    # Get the signature from the header
    my $signature = $cgi->http('X-CCAI-Signature');
    
    # Verify the signature if provided
    my $is_valid = 1;
    if ($signature) {
        $is_valid = $ccai->webhook->verify_signature($signature, $json, $webhook_secret);
    }
    
    if ($is_valid) {
        # Parse the webhook event
        my $event = $ccai->webhook->parse_event($json);
        
        if ($event) {
            # Process different event types
            if ($event->{type} eq 'message.sent') {
                # Handle message.sent event
                my $to = $event->{to};
                my $message = $event->{message};
                
                # Log the event (in a real application, you might store this in a database)
                log_event("Message sent to $to: $message");
                
                # You could trigger other actions here based on the event
                
            } elsif ($event->{type} eq 'message.received') {
                # Handle message.received event
                my $from = $event->{from};
                my $message = $event->{message};
                
                log_event("Message received from $from: $message");
                
                # You could implement auto-replies or other logic here
            }
            
            # Return a success response
            print encode_json({ status => 'success', message => "Processed $event->{type} event" });
        } else {
            # Return an error response
            print encode_json({ status => 'error', message => 'Invalid event format' });
        }
    } else {
        # Return an error response for invalid signature
        print encode_json({ status => 'error', message => 'Invalid signature' });
    }
} else {
    # Return a simple response for non-POST requests
    print encode_json({ status => 'error', message => 'Only POST requests are accepted' });
}

# Simple logging function
sub log_event {
    my ($message) = @_;
    
    my $timestamp = scalar localtime;
    open my $log, '>>', 'webhook_events.log' or die "Cannot open log file: $!";
    print $log "[$timestamp] $message\n";
    close $log;
}