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
