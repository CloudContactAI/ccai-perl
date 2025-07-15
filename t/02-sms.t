#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 12;

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
$response = $sms->send([{first_name => 'John', last_name => 'Doe', phone => '+1234567890'}], '', 'test title');
is($response->{success}, 0, 'SMS send fails with empty message');
like($response->{error}, qr/message is required/i, 'Correct error for empty message');

# Test 3: SMS send validation - missing title
$response = $sms->send([{first_name => 'John', last_name => 'Doe', phone => '+1234567890'}], 'test message', '');
is($response->{success}, 0, 'SMS send fails with empty title');
like($response->{error}, qr/campaign title is required/i, 'Correct error for empty title');

# Test 4: SMS send validation - missing first_name
$response = $sms->send([{last_name => 'Doe', phone => '+1234567890'}], 'test message', 'test title');
is($response->{success}, 0, 'SMS send fails with missing first_name');
like($response->{error}, qr/first name is required/i, 'Correct error for missing first_name');

# Test 5: SMS send validation - missing last_name
$response = $sms->send([{first_name => 'John', phone => '+1234567890'}], 'test message', 'test title');
is($response->{success}, 0, 'SMS send fails with missing last_name');
like($response->{error}, qr/last name is required/i, 'Correct error for missing last_name');

# Test 6: SMS send validation - missing phone
$response = $sms->send([{first_name => 'John', last_name => 'Doe'}], 'test message', 'test title');
is($response->{success}, 0, 'SMS send fails with missing phone');
like($response->{error}, qr/phone number is required/i, 'Correct error for missing phone');

done_testing();
