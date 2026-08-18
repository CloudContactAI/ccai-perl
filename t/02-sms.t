#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 16;

use lib '../lib';
use CCAI;

# Create CCAI instance for testing
my $ccai = CCAI->new({
    client_id => 'test-client-id',
    api_key   => 'test-api-key'
});

my $sms = $ccai->sms;

# Test 1: SMS send validation - empty accounts
my $response = $sms->send([], 'test message', 'test title');
is($response->{success}, 0, 'SMS send fails with empty accounts array');
like($response->{error}, qr/at least one account/i, 'Correct error for empty accounts');

# Test 2: SMS send validation - missing message
$response = $sms->send([{firstName => 'John', lastName => 'Doe', phone => '+1234567890'}], '', 'test title');
is($response->{success}, 0, 'SMS send fails with empty message');
like($response->{error}, qr/message is required/i, 'Correct error for empty message');

# Test 3: SMS send validation - missing title
$response = $sms->send([{firstName => 'John', lastName => 'Doe', phone => '+1234567890'}], 'test message', '');
is($response->{success}, 0, 'SMS send fails with empty title');
like($response->{error}, qr/campaign title is required/i, 'Correct error for empty title');

# Test 4: SMS send validation - missing firstName
$response = $sms->send([{lastName => 'Doe', phone => '+1234567890'}], 'test message', 'test title');
is($response->{success}, 0, 'SMS send fails with missing firstName');
like($response->{error}, qr/first name is required/i, 'Correct error for missing firstName');

# Test 5: SMS send validation - missing lastName
$response = $sms->send([{firstName => 'John', phone => '+1234567890'}], 'test message', 'test title');
is($response->{success}, 0, 'SMS send fails with missing lastName');
like($response->{error}, qr/last name is required/i, 'Correct error for missing lastName');

# Test 6: SMS send validation - missing phone
$response = $sms->send([{firstName => 'John', lastName => 'Doe'}], 'test message', 'test title');
is($response->{success}, 0, 'SMS send fails with missing phone');
like($response->{error}, qr/phone number is required/i, 'Correct error for missing phone');

done_testing();

# Test 13: send_with_template builds payload with templateId
my $template_response = $sms->send_with_template(
    [{firstName => 'John', lastName => 'Doe', phone => '+1234567890'}],
    12345,
    'Template Campaign'
);
# Validation passes (templateId replaces message requirement)
isnt($template_response->{error}, 'Message is required', 'send_with_template does not require message');

# Test 14: send_with_template passes empty message
my $captured = undef;
{
    no warnings 'redefine';
    local *CCAI::request = sub {
        my ($self, $method, $endpoint, $data) = @_;
        $captured = $data;
        return { success => 1, data => { id => 'msg-tpl-1', status => 'sent' } };
    };
    $sms->send_with_template(
        [{firstName => 'John', lastName => 'Doe', phone => '+15551234567'}],
        12345,
        'Template Campaign'
    );
}
is($captured->{templateId}, 12345, 'send_with_template sets templateId in payload');
is($captured->{message}, '', 'send_with_template sends empty message');

# Test 15: send_single_with_template builds correct account
my $single_captured = undef;
{
    no warnings 'redefine';
    local *CCAI::request = sub {
        my ($self, $method, $endpoint, $data) = @_;
        $single_captured = $data;
        return { success => 1, data => { id => 'msg-tpl-2', status => 'sent' } };
    };
    $sms->send_single_with_template('Jane', 'Smith', '+15559876543', 99, 'Single Template');
}
is($single_captured->{templateId}, 99, 'send_single_with_template sets templateId');
is($single_captured->{accounts}[0]{firstName}, 'Jane', 'send_single_with_template sets correct account');

