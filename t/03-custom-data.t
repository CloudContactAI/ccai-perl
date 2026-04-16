#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 17;
use JSON;

use lib 'lib';
use CCAI;

# Test customData functionality

# Mock CCAI instance for testing
my $ccai = CCAI->new({
    client_id => 'test-client-id',
    api_key   => 'test-api-key'
});

# Test 1: SMS send with data (template variable substitution)
{
    my @accounts = (
        {
            firstName => "John",
            lastName  => "Doe",
            phone     => "+15551234567",
            data      => {
                order_id      => "ORD-12345",
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
        "Hello \${firstName}, your order \${order_id} is ready!",
        "Test Campaign"
    );

    ok($response->{success}, "SMS send with data succeeds");
    ok(exists $captured_data->{accounts}->[0]->{data}, "data field is included in request (wire: 'data')");
    is($captured_data->{accounts}->[0]->{data}->{order_id}, "ORD-12345", "Order ID is preserved in data");
    is($captured_data->{accounts}->[0]->{data}->{customer_type}, "premium", "Customer type is preserved in data");
}

# Test 1b: SMS send() maps customData → messageData (wire format)
{
    my @accounts = (
        {
            firstName  => "John",
            lastName   => "Doe",
            phone      => "+15551234567",
            customData => '{"source":"sms-test"}'
        }
    );

    my $captured_data;
    no warnings 'redefine';
    local *CCAI::request = sub {
        my ($self, $method, $endpoint, $data) = @_;
        $captured_data = $data;
        return { success => 1, data => {} };
    };

    $ccai->sms->send(\@accounts, "Hello!", "Test");

    ok(!exists $captured_data->{accounts}->[0]->{customData}, "customData key removed from wire payload");
    ok(exists  $captured_data->{accounts}->[0]->{messageData}, "messageData key present in wire payload");
    is($captured_data->{accounts}->[0]->{messageData}, '{"source":"sms-test"}', "messageData value preserved");
}

# Test 2: SMS send_single with data (template vars) and messageData (webhook string)
{
    my $template_data = {
        appointment_id => "APPT-789",
        service_type   => "consultation"
    };
    my $message_data = '{"source":"sms-test","ref":"APPT-789"}';

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
        "Hi \${firstName}, your \${service_type} is \${appointment_id}!",
        "Single Test",
        undef,          # options
        $template_data, # data (template variables → wire: "data")
        $message_data   # message_data (webhook payload → wire: "messageData")
    );

    ok($response->{success}, "SMS send_single with data and messageData succeeds");
    ok(exists $captured_data->{accounts}->[0]->{data}, "data field included (wire: 'data')");
    is($captured_data->{accounts}->[0]->{data}->{appointment_id}, "APPT-789", "Appointment ID preserved in data");
    is($captured_data->{accounts}->[0]->{data}->{service_type}, "consultation", "Service type preserved in data");
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
        "Hi \${firstName}!",
        "Backward Compatibility Test"
    );
    
    ok($response->{success}, "SMS send_single without data succeeds (backward compatibility)");
    ok(!exists $captured_data->{accounts}->[0]->{data}, "No data field when not provided");
    ok(!exists $captured_data->{accounts}->[0]->{messageData}, "No messageData field when not provided");
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
