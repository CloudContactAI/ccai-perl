#!/usr/bin/env perl

use strict;
use warnings;
use 5.016;

use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use JSON;

# Create a user agent
my $ua = LWP::UserAgent->new;

# Create a test webhook payload
my $payload = {
    type => "message.sent",
    from => "+15551234567",
    to => "+14155551212",
    message => "Test webhook from Perl",
    timestamp => time()
};

# Convert to JSON
my $json = encode_json($payload);

# Create the request
my $req = POST 'http://localhost:3000',
    Content_Type => 'application/json',
    Content => $json;

# Add a test signature header
$req->header('X-CCAI-Signature' => 'test-signature-123');

# Send the request
print "Sending test webhook to http://localhost:3000...\n";
my $res = $ua->request($req);

# Check the response
if ($res->is_success) {
    print "Success: " . $res->decoded_content . "\n";
} else {
    print "Error: " . $res->status_line . "\n";
}