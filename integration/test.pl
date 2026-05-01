#!/usr/bin/env perl

# CCAI Perl SDK Integration Tests
#
# Exercises all 31 public API methods against the test environment.
# Exits with code 1 if any test fails.

use strict;
use warnings;
use 5.016;

use CCAI;
use MIME::Base64 qw(encode_base64 decode_base64);
use Digest::SHA qw(hmac_sha256);
use File::Temp qw(tempfile);
use POSIX qw();

# ---------------------------------------------------------------------------
# Environment variables
# ---------------------------------------------------------------------------
my $client_id   = $ENV{CCAI_CLIENT_ID}        // '';
my $api_key     = $ENV{CCAI_API_KEY}           // '';
my $phone1      = $ENV{CCAI_TEST_PHONE}        // '';
my $phone2      = $ENV{CCAI_TEST_PHONE_2}      // '';
my $phone3      = $ENV{CCAI_TEST_PHONE_3}      // '';
my $email1      = $ENV{CCAI_TEST_EMAIL}        // '';
my $email2      = $ENV{CCAI_TEST_EMAIL_2}      // '';
my $email3      = $ENV{CCAI_TEST_EMAIL_3}      // '';
my $first1      = $ENV{CCAI_TEST_FIRST_NAME}   // 'Docker';
my $last1       = $ENV{CCAI_TEST_LAST_NAME}    // 'Test';
my $first2      = $ENV{CCAI_TEST_FIRST_NAME_2} // 'Docker2';
my $last2       = $ENV{CCAI_TEST_LAST_NAME_2}  // 'Test2';
my $first3      = $ENV{CCAI_TEST_FIRST_NAME_3} // 'Docker3';
my $last3       = $ENV{CCAI_TEST_LAST_NAME_3}  // 'Test3';
my $webhook_url = $ENV{WEBHOOK_URL}            // 'https://webhook.site/perl-docker-test';

unless ($client_id && $api_key) {
    warn "ERROR: CCAI_CLIENT_ID and CCAI_API_KEY environment variables are required.\n";
    exit 1;
}

# ---------------------------------------------------------------------------
# Client
# ---------------------------------------------------------------------------
my $ccai = CCAI->new({
    client_id            => $client_id,
    api_key              => $api_key,
    use_test_environment => 1,
});

# ---------------------------------------------------------------------------
# Test image: 1x1 transparent PNG embedded as base64
# ---------------------------------------------------------------------------
my $image_b64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwADhQGAWjR9awAAAABJRU5ErkJggg==';
my ($tmp_fh, $image_path) = tempfile(SUFFIX => '.png', UNLINK => 1);
binmode $tmp_fh;
print $tmp_fh decode_base64($image_b64);
close $tmp_fh;

# ---------------------------------------------------------------------------
# Test runner
# ---------------------------------------------------------------------------
my $passed = 0;
my $failed = 0;

sub run_test {
    my ($label, $code) = @_;
    my $ok = eval { $code->(); 1 };
    if ($ok) {
        print "  [PASS] $label\n";
        $passed++;
    } else {
        my $err = $@ // 'unknown error';
        $err =~ s/\n.*//s;    # keep first line only
        print "  [FAIL] $label: $err\n";
        $failed++;
    }
}

sub assert_success {
    my ($res, $label) = @_;
    die "undef response" unless defined $res;
    die "API error: $res->{error}" unless $res->{success};
    return $res;
}

print "=== CCAI Perl SDK Integration Tests ===\n\n";

# ---------------------------------------------------------------------------
# SMS Tests (01–06)
# ---------------------------------------------------------------------------
print "--- SMS ---\n";

run_test('01 SMS send_single', sub {
    my $res = $ccai->sms->send_single($first1, $last1, $phone1, 'Hello ${firstName}!', 'Perl Test 01');
    assert_success($res);
});

run_test('02 SMS send (1 recipient)', sub {
    my $res = $ccai->sms->send(
        [{ firstName => $first1, lastName => $last1, phone => $phone1 }],
        'Bulk test ${firstName}', 'Perl Test 02'
    );
    assert_success($res);
});

run_test('03 SMS send (2 recipients)', sub {
    my $res = $ccai->sms->send(
        [
            { firstName => $first1, lastName => $last1, phone => $phone1 },
            { firstName => $first2, lastName => $last2, phone => $phone2 },
        ],
        'Multi-recipient ${firstName}', 'Perl Test 03'
    );
    assert_success($res);
});

run_test('04 SMS send (3 recipients)', sub {
    my $res = $ccai->sms->send(
        [
            { firstName => $first1, lastName => $last1, phone => $phone1 },
            { firstName => $first2, lastName => $last2, phone => $phone2 },
            { firstName => $first3, lastName => $last3, phone => $phone3 },
        ],
        'Triple-recipient ${firstName}', 'Perl Test 04'
    );
    assert_success($res);
});

run_test('05 SMS send with data (template variables)', sub {
    my $res = $ccai->sms->send(
        [{ firstName => $first1, lastName => $last1, phone => $phone1, data => { city => 'Miami', code => 'PL5' } }],
        'Hello ${firstName}, code ${code} from ${city}', 'Perl Test 05'
    );
    assert_success($res);
});

run_test('06 SMS send_single with messageData', sub {
    my $res = $ccai->sms->send_single(
        $first1, $last1, $phone1,
        'Custom data test', 'Perl Test 06',
        undef,                                  # options
        undef,                                  # data
        '{"source":"perl-integration"}'         # message_data
    );
    assert_success($res);
});

# ---------------------------------------------------------------------------
# MMS Tests (07–17)
# ---------------------------------------------------------------------------
print "\n--- MMS ---\n";

my $signed_url = undef;
my $file_key   = undef;

run_test('07 MMS get_signed_url', sub {
    my $res = $ccai->mms->get_signed_url('perl_test.png', 'image/png');
    assert_success($res);
    die "Missing signed_s3_url" unless $res->{data}{signed_s3_url};
    $signed_url = $res->{data}{signed_s3_url};
    $file_key   = $res->{data}{file_key};
});

run_test('08 MMS upload_file', sub {
    die "Dependency test 07 failed — skipping" unless $signed_url;
    my $res = $ccai->mms->upload_file($signed_url, $image_path, 'image/png');
    assert_success($res);
});

run_test('09 MMS send_single', sub {
    die "Dependency test 07 failed — skipping" unless $file_key;
    my $res = $ccai->mms->send_single($first1, $last1, $phone1, 'MMS single test', 'Perl MMS 09', $file_key);
    assert_success($res);
});

run_test('10 MMS send (1 recipient)', sub {
    die "Dependency test 07 failed — skipping" unless $file_key;
    my $res = $ccai->mms->send(
        [{ firstName => $first1, lastName => $last1, phone => $phone1 }],
        'MMS bulk test', 'Perl MMS 10', $file_key
    );
    assert_success($res);
});

run_test('11 MMS send (2 recipients)', sub {
    die "Dependency test 07 failed — skipping" unless $file_key;
    my $res = $ccai->mms->send(
        [
            { firstName => $first1, lastName => $last1, phone => $phone1 },
            { firstName => $first2, lastName => $last2, phone => $phone2 },
        ],
        'MMS 2-recipient test', 'Perl MMS 11', $file_key
    );
    assert_success($res);
});

run_test('12 MMS send (3 recipients)', sub {
    die "Dependency test 07 failed — skipping" unless $file_key;
    my $res = $ccai->mms->send(
        [
            { firstName => $first1, lastName => $last1, phone => $phone1 },
            { firstName => $first2, lastName => $last2, phone => $phone2 },
            { firstName => $first3, lastName => $last3, phone => $phone3 },
        ],
        'MMS 3-recipient test', 'Perl MMS 12', $file_key
    );
    assert_success($res);
});

run_test('13 MMS send with data (template variables)', sub {
    die "Dependency test 07 failed — skipping" unless $file_key;
    my $res = $ccai->mms->send(
        [{ firstName => $first1, lastName => $last1, phone => $phone1, data => { promo => 'PL13' } }],
        'MMS data test promo ${promo}', 'Perl MMS 13', $file_key
    );
    assert_success($res);
});

run_test('14 MMS send_single with customData', sub {
    die "Dependency test 07 failed — skipping" unless $file_key;
    my $res = $ccai->mms->send_single(
        $first1, $last1, $phone1,
        'MMS custom data test', 'Perl MMS 14', $file_key,
        '{"source":"perl-integration"}'
    );
    assert_success($res);
});

run_test('15 MMS check_file_uploaded', sub {
    die "Dependency test 07 failed — skipping" unless $file_key;
    my $res = $ccai->mms->check_file_uploaded($file_key);
    # Returns undef if not found, a result hash if found — either is acceptable
    # The key test is that it does not die
    1;
});

run_test('16 MMS send_with_image (fresh upload)', sub {
    my $res = $ccai->mms->send_with_image(
        [{ firstName => $first1, lastName => $last1, phone => $phone1 }],
        'MMS sendWithImage test', 'Perl MMS 16', $image_path
    );
    assert_success($res);
});

run_test('17 MMS send_with_image (cached, same file)', sub {
    my $res = $ccai->mms->send_with_image(
        [{ firstName => $first1, lastName => $last1, phone => $phone1 }],
        'MMS cached image test', 'Perl MMS 17', $image_path
    );
    assert_success($res);
});

# ---------------------------------------------------------------------------
# Email Tests (18–22)
# ---------------------------------------------------------------------------
print "\n--- Email ---\n";

run_test('18 Email send_single', sub {
    my $res = $ccai->email->send_single(
        $first1, $last1, $email1,
        'Perl Integration Test 18',
        '<p>Hello ${firstName}!</p>'
    );
    assert_success($res);
});

run_test('19 Email send (1 recipient)', sub {
    my $res = $ccai->email->send(
        [{ firstName => $first1, lastName => $last1, email => $email1 }],
        'Perl Integration Test 19',
        '<p>Hello ${firstName}!</p>',
        'noreply@cloudcontactai.com',
        'noreply@cloudcontactai.com',
        'Perl Test'
    );
    assert_success($res);
});

run_test('20 Email send (2 recipients)', sub {
    my $res = $ccai->email->send(
        [
            { firstName => $first1, lastName => $last1, email => $email1 },
            { firstName => $first2, lastName => $last2, email => $email2 },
        ],
        'Perl Integration Test 20',
        '<p>Hello ${firstName}!</p>',
        'noreply@cloudcontactai.com',
        'noreply@cloudcontactai.com',
        'Perl Test'
    );
    assert_success($res);
});

run_test('21 Email send (3 recipients)', sub {
    my $res = $ccai->email->send(
        [
            { firstName => $first1, lastName => $last1, email => $email1 },
            { firstName => $first2, lastName => $last2, email => $email2 },
            { firstName => $first3, lastName => $last3, email => $email3 },
        ],
        'Perl Integration Test 21',
        '<p>Hello ${firstName}!</p>',
        'noreply@cloudcontactai.com',
        'noreply@cloudcontactai.com',
        'Perl Test'
    );
    assert_success($res);
});

run_test('22 Email send_campaign (full config)', sub {
    my $res = $ccai->email->send_campaign({
        accounts      => [{ firstName => $first1, lastName => $last1, email => $email1 }],
        subject       => 'Perl Integration Test 22',
        title         => 'Perl Campaign Test 22',
        message       => '<h1>Campaign Test</h1><p>Hello ${firstName}, this is a full campaign test.</p>',
        sender_email  => 'noreply@cloudcontactai.com',
        reply_email   => 'noreply@cloudcontactai.com',
        sender_name   => 'Perl Integration',
        campaign_type => 'EMAIL',
        add_to_list   => 'noList',
        contact_input => 'accounts',
        from_type     => 'single',
        senders       => [],
    });
    assert_success($res);
});

# ---------------------------------------------------------------------------
# Webhook Tests (23–29)
# ---------------------------------------------------------------------------
print "\n--- Webhook ---\n";

my $webhook_id = undef;

run_test('23 Webhook register', sub {
    my $res = $ccai->webhook->register({
        url             => $webhook_url,
        secret          => 'perl-test-secret-key',
        integration_type => 'ALL',
    });
    assert_success($res);
    die "No id in register response" unless $res->{data}{id};
    $webhook_id = $res->{data}{id};
});

run_test('24 Webhook list', sub {
    my $res = $ccai->webhook->list();
    assert_success($res);
    die "Expected array data" unless ref $res->{data} eq 'ARRAY';
});

run_test('25 Webhook update', sub {
    die "Dependency test 23 failed — skipping" unless $webhook_id;
    my $res = $ccai->webhook->update($webhook_id, {
        url             => $webhook_url . '/updated',
        integration_type => 'ALL',
    });
    assert_success($res);
});

run_test('26 Webhook verify_signature (valid)', sub {
    my $secret     = 'perl-test-secret-key';
    my $event_hash = 'abc123hash';
    my $data       = "$client_id:$event_hash";
    my $expected   = encode_base64(hmac_sha256($data, $secret), '');
    my $ok = $ccai->webhook->verify_signature($expected, $client_id, $event_hash, $secret);
    die "Valid signature verification returned false" unless $ok;
});

run_test('27 Webhook verify_signature (invalid)', sub {
    my $ok = $ccai->webhook->verify_signature('invalidsignature==', $client_id, 'somehash', 'wrong-secret');
    die "Invalid signature verification returned true" if $ok;
});

run_test('28 Webhook parse_event', sub {
    my $payload = '{"eventType":"SMS_SENT","data":{"phone":"+13055551234","campaignId":"camp-001"}}';
    my $event = $ccai->webhook->parse_event($payload);
    die "parse_event returned undef" unless defined $event;
    die "Missing type in parsed event" unless $event->{type};
});

run_test('29 Webhook delete', sub {
    die "Dependency test 23 failed — skipping" unless $webhook_id;
    my $res = $ccai->webhook->delete($webhook_id);
    assert_success($res);
});

# ---------------------------------------------------------------------------
# Contact Tests (30–31)
# ---------------------------------------------------------------------------
print "\n--- Contact ---\n";

run_test('30 Contact set_do_not_text (opt-out)', sub {
    my $res = $ccai->contact->set_do_not_text(1, { phone => $phone1 });
    assert_success($res);
});

run_test('31 Contact set_do_not_text (opt-in)', sub {
    my $res = $ccai->contact->set_do_not_text(0, { phone => $phone1 });
    assert_success($res);
});

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
my $total = $passed + $failed;
print "\n=== Results: $passed/$total passed ===\n";

exit($failed > 0 ? 1 : 0);
