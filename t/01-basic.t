#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 16;
use Test::Exception;

use lib '../lib';

# Test 1: Module loading
BEGIN {
    use_ok('CCAI') || print "Bail out!\n";
    use_ok('CCAI::SMS') || print "Bail out!\n";
    use_ok('CCAI::MMS') || print "Bail out!\n";
}

# Test 2: CCAI constructor validation
dies_ok {
    CCAI->new();
} 'CCAI constructor dies without config';

dies_ok {
    CCAI->new({});
} 'CCAI constructor dies without client_id';

dies_ok {
    CCAI->new({ client_id => 'test' });
} 'CCAI constructor dies without api_key';

# Test 3: CCAI constructor success
my $ccai;
lives_ok {
    $ccai = CCAI->new({
        client_id => 'test-client-id',
        api_key   => 'test-api-key'
    });
} 'CCAI constructor succeeds with required params';

isa_ok($ccai, 'CCAI', 'CCAI object created');

# Test 4: CCAI accessors
is($ccai->get_client_id(), 'test-client-id', 'get_client_id returns correct value');
is($ccai->get_api_key(), 'test-api-key', 'get_api_key returns correct value');
is($ccai->get_base_url(), 'https://core.cloudcontactai.com/api', 'get_base_url returns default value');

# Test 5: Service objects
isa_ok($ccai->sms, 'CCAI::SMS', 'SMS service object created');
isa_ok($ccai->mms, 'CCAI::MMS', 'MMS service object created');

# Test 6: SMS validation
my $sms_response = $ccai->sms->send([], 'test', 'test');
is($sms_response->{success}, 0, 'SMS send fails with empty accounts');
like($sms_response->{error}, qr/at least one account/i, 'SMS error message is correct');

# Test 7: MMS validation  
my $mms_response = $ccai->mms->get_signed_url('', 'image/jpeg');
is($mms_response->{success}, 0, 'MMS get_signed_url fails with empty filename');
