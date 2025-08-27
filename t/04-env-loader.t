#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 11;
use File::Temp qw(tempfile);

use lib 'lib';
use CCAI::EnvLoader;

# Test 1: Load non-existent .env file (should warn but not die)
{
    my $result = CCAI::EnvLoader->load('/non/existent/file');
    ok(!defined $result, "Loading non-existent file returns undef");
}

# Test 2: Load valid .env file
{
    my ($fh, $filename) = tempfile(SUFFIX => '.env', UNLINK => 1);
    print $fh "TEST_KEY=test_value\n";
    print $fh "QUOTED_KEY=\"quoted value\"\n";
    print $fh "SINGLE_QUOTED='single quoted'\n";
    print $fh "# This is a comment\n";
    print $fh "\n";  # Empty line
    print $fh "SPACES_KEY = value with spaces \n";
    close $fh;
    
    # Clear any existing env vars
    delete $ENV{TEST_KEY};
    delete $ENV{QUOTED_KEY};
    delete $ENV{SINGLE_QUOTED};
    delete $ENV{SPACES_KEY};
    
    my $result = CCAI::EnvLoader->load($filename);
    ok($result, "Loading valid .env file succeeds");
    is($ENV{TEST_KEY}, 'test_value', "Simple key=value works");
    is($ENV{QUOTED_KEY}, 'quoted value', "Double quoted values work");
    is($ENV{SINGLE_QUOTED}, 'single quoted', "Single quoted values work");
    is($ENV{SPACES_KEY}, 'value with spaces', "Values with spaces work");
}

# Test 3: Don't override existing environment variables
{
    my ($fh, $filename) = tempfile(SUFFIX => '.env', UNLINK => 1);
    print $fh "EXISTING_VAR=from_file\n";
    close $fh;
    
    $ENV{EXISTING_VAR} = 'from_env';
    CCAI::EnvLoader->load($filename);
    is($ENV{EXISTING_VAR}, 'from_env', "Existing env vars are not overridden");
}

# Test 4: get_ccai_credentials with valid credentials
{
    $ENV{CCAI_CLIENT_ID} = 'test_client_id';
    $ENV{CCAI_API_KEY} = 'test_api_key';
    
    my ($client_id, $api_key) = CCAI::EnvLoader->get_ccai_credentials();
    is($client_id, 'test_client_id', "Client ID retrieved correctly");
    is($api_key, 'test_api_key', "API key retrieved correctly");
}

# Test 5: get_ccai_credentials with missing credentials
{
    delete $ENV{CCAI_CLIENT_ID};
    delete $ENV{CCAI_API_KEY};
    
    eval {
        CCAI::EnvLoader->get_ccai_credentials();
    };
    ok($@, "Missing credentials throws error");
    like($@, qr/CCAI_CLIENT_ID.*required/, "Error message mentions missing CLIENT_ID");
}

done_testing();
