#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 10;

use lib '../lib';
use CCAI;

# Create CCAI instance for testing
my $ccai = CCAI->new({
    client_id => 'test-client-id',
    api_key   => 'test-api-key'
});

my $mms = $ccai->mms;

# Test 1: MMS get_signed_url validation - missing file_name
my $response = $mms->get_signed_url('', 'image/jpeg');
is($response->{success}, 0, 'get_signed_url fails with empty file_name');
like($response->{error}, qr/file name is required/i, 'Correct error for empty file_name');

# Test 2: MMS get_signed_url validation - missing file_type
$response = $mms->get_signed_url('test.jpg', '');
is($response->{success}, 0, 'get_signed_url fails with empty file_type');
like($response->{error}, qr/file type is required/i, 'Correct error for empty file_type');

# Test 3: MMS upload_file validation - missing signed_url
$response = $mms->upload_file('', 'test.jpg', 'image/jpeg');
is($response->{success}, 0, 'upload_file fails with empty signed_url');
like($response->{error}, qr/signed url is required/i, 'Correct error for empty signed_url');

# Test 4: MMS upload_file validation - missing file_path
$response = $mms->upload_file('https://example.com/signed-url', '', 'image/jpeg');
is($response->{success}, 0, 'upload_file fails with empty file_path');
like($response->{error}, qr/file path is required/i, 'Correct error for empty file_path');

# Test 5: MMS upload_file validation - file not found
$response = $mms->upload_file('https://example.com/signed-url', 'nonexistent.jpg', 'image/jpeg');
is($response->{success}, 0, 'upload_file fails with nonexistent file');
like($response->{error}, qr/file not found/i, 'Correct error for nonexistent file');

done_testing();
