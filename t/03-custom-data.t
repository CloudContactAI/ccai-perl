#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 13;
use JSON;

use lib 'lib';
use CCAI;

# Test customData functionality

# Mock CCAI instance for testing
my $ccai = CCAI->new({
    client_id => 'test-client-id',
    api_key   => 'test-api-key'
});

# Test 1: SMS send with customData
{
    my @accounts = (
        {
            first_name => "John",
            last_name  => "Doe",
            phone      => "+15551234567",
            customData => {
                order_id => "ORD-12345",
                customer_type => "premium"
            }
        }
    );
    
    # Mock the request method to capture the data being sent
    my $captured_data;
    no warnings 'redefine';
    local *CCAI::request = sub {
        my ($self, $method, $endpoint, $data) = @_;
        $captured_data = $data;
        return {
            success => 1,
            data => { campaign_id => "test-campaign-123" }
        };
    };
    
    my $response = $ccai->sms->send(
        \@accounts,
        "Hello \${first_name}!",
        "Test Campaign"
    );
    
    ok($response->{success}, "SMS send with customData succeeds");
    ok(exists $captured_data->{accounts}->[0]->{customData}, "CustomData is included in request");
    is($captured_data->{accounts}->[0]->{customData}->{order_id}, "ORD-12345", "Order ID is preserved");
    is($captured_data->{accounts}->[0]->{customData}->{customer_type}, "premium", "Customer type is preserved");
}

# Test 2: SMS send_single with customData
{
    my $custom_data = {
        appointment_id => "APPT-789",
        service_type => "consultation"
    };
    
    my $captured_data;
    no warnings 'redefine';
    local *CCAI::request = sub {
        my ($self, $method, $endpoint, $data) = @_;
        $captured_data = $data;
        return {
            success => 1,
            data => { campaign_id => "test-campaign-456" }
        };
    };
    
    my $response = $ccai->sms->send_single(
        "Jane",
        "Smith",
        "+15559876543",
        "Hi \${first_name}!",
        "Single Test",
        undef,  # options
        $custom_data
    );
    
    ok($response->{success}, "SMS send_single with customData succeeds");
    ok(exists $captured_data->{accounts}->[0]->{customData}, "CustomData is included in single send");
    is($captured_data->{accounts}->[0]->{customData}->{appointment_id}, "APPT-789", "Appointment ID is preserved");
    is($captured_data->{accounts}->[0]->{customData}->{service_type}, "consultation", "Service type is preserved");
}

# Test 3: SMS send_single without customData (backward compatibility)
{
    my $captured_data;
    no warnings 'redefine';
    local *CCAI::request = sub {
        my ($self, $method, $endpoint, $data) = @_;
        $captured_data = $data;
        return {
            success => 1,
            data => { campaign_id => "test-campaign-789" }
        };
    };
    
    my $response = $ccai->sms->send_single(
        "Bob",
        "Wilson",
        "+15551112222",
        "Hi \${first_name}!",
        "Backward Compatibility Test"
    );
    
    ok($response->{success}, "SMS send_single without customData succeeds (backward compatibility)");
    ok(!exists $captured_data->{accounts}->[0]->{customData}, "No customData field when not provided");
}

# Test 4: Webhook parse_event with customData
{
    my $webhook_event = {
        type => "message.sent",
        id => "msg_12345",
        to => "+15551234567",
        message => "Hello John!",
        timestamp => "2025-08-27T00:31:51.982Z",
        customData => {
            order_id => "ORD-12345",
            customer_type => "premium",
            items => ["laptop", "mouse"]
        }
    };
    
    my $json = JSON->new->encode($webhook_event);
    my $parsed_event = $ccai->webhook->parse_event($json);
    
    ok($parsed_event, "Webhook event with customData parses successfully");
    ok(exists $parsed_event->{customData}, "CustomData is present in parsed event");
    is($parsed_event->{customData}->{order_id}, "ORD-12345", "CustomData order_id is preserved in webhook");
}

done_testing();
