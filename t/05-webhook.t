#!/usr/bin/env perl

use strict;
use warnings;
use 5.016;

use Test::More;
use JSON::PP;
use Digest::SHA qw(hmac_sha256);
use MIME::Base64 qw(encode_base64);

# Mock the CCAI module for testing
package TestCCAI;

sub new {
    my $class = shift;
    my $self = {
        client_id => 'test-client',
        json => JSON::PP->new,
        request_calls => []
    };
    bless $self, $class;
    return $self;
}

sub get_client_id {
    my $self = shift;
    return $self->{client_id};
}

sub request {
    my ($self, $method, $endpoint, $payload) = @_;

    # Store the call for inspection
    push @{$self->{request_calls}}, {
        method => $method,
        endpoint => $endpoint,
        payload => $payload
    };

    # Simple mock response
    if ($method eq 'POST' && $endpoint =~ /integration/) {
        return {
            success => 1,
            data => [{
                id => 'webhook_123',
                url => $payload->[0]->{url},
                method => 'POST',
                integrationType => 'ALL',
                secretKey => $payload->[0]->{secretKey} // 'sk_live_auto_generated'
            }]
        };
    }

    return { success => 1, data => [] };
}

# Back to the test package
package main;

use lib 'lib';
require CCAI::Webhook;

my $ccai = TestCCAI->new();
my $webhook = CCAI::Webhook->new($ccai);

# Test 1: Register webhook without secret (auto-generation)
my $result1 = $webhook->register({
    url => 'https://example.com/webhook'
});

ok($result1->{success}, 'Register webhook without secret succeeds');
is($result1->{data}->{url}, 'https://example.com/webhook', 'Webhook URL is set correctly');

# Check that secretKey was NOT included in the payload
my $last_call = $ccai->{request_calls}->[-1];
my $payload = $last_call->{payload}->[0];
ok(!exists $payload->{secretKey} || !defined $payload->{secretKey},
   'secretKey not included in payload when not provided');

# Test 2: Register webhook with custom secret
my $result2 = $webhook->register({
    url => 'https://example.com/webhook-custom',
    secret => 'my-custom-secret'
});

ok($result2->{success}, 'Register webhook with custom secret succeeds');
is($result2->{data}->{url}, 'https://example.com/webhook-custom', 'Custom webhook URL is set correctly');

# Check that secretKey WAS included in the payload
$last_call = $ccai->{request_calls}->[-1];
$payload = $last_call->{payload}->[0];
ok(defined $payload->{secretKey}, 'secretKey is included in payload when provided');
is($payload->{secretKey}, 'my-custom-secret', 'secretKey value is correct');

# Test 3: Verify signature (valid)
my $client_id = 'test-client-id';
my $event_hash = 'event-hash-abc123';
my $secret = 'test-secret';

# Compute expected signature: HMAC-SHA256(secretKey, clientId:eventHash) in Base64
my $data = "$client_id:$event_hash";
my $computed = hmac_sha256($data, $secret);
my $valid_sig = encode_base64($computed, '');  # Remove trailing newline

my $is_valid = $webhook->verify_signature($valid_sig, $client_id, $event_hash, $secret);
ok($is_valid, 'Valid signature is verified');

# Test 4: Verify signature (invalid)
my $is_invalid = $webhook->verify_signature('bad-sig', $client_id, $event_hash, $secret);
ok(!$is_invalid, 'Invalid signature is rejected');

# Test 5: Verify missing parameters
ok(!$webhook->verify_signature(undef, $client_id, $event_hash, $secret), 'Missing signature is rejected');
ok(!$webhook->verify_signature('sig', undef, $event_hash, $secret), 'Missing client_id is rejected');
ok(!$webhook->verify_signature('sig', $client_id, undef, $secret), 'Missing event_hash is rejected');
ok(!$webhook->verify_signature('sig', $client_id, $event_hash, undef), 'Missing secret is rejected');

done_testing(13);
