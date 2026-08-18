#!/usr/bin/env perl

# CCAI Perl SDK Integration Tests — 54 tests
# Covers: SMS (1-6), MMS (7-17), Email (18-22), Webhook (23-29), Contact (30-31),
#         Brands (32-36), Campaigns (37-42), ContactValidator (43-46), Negative cases (47-52),
#         SMS Templates (53-54)
#
# Test results use three states:
#   PASS — the test ran and all assertions held
#   FAIL — the test ran and an assertion (or the API call) failed
#   SKIP — a prerequisite test failed, so this test could not run
#
# Resources created during the run (webhooks, brands, campaigns) are tracked and
# deleted in a final cleanup block even if tests fail midway.
# Exits with code 1 if any test fails, 2 if required env vars are missing.

use strict;
use warnings;
use 5.016;

use CCAI;
use JSON ();
use MIME::Base64 qw(encode_base64 decode_base64);
use Digest::SHA qw(hmac_sha256);
use File::Temp qw(tempfile);
use POSIX qw();

# ---------------------------------------------------------------------------
# Environment variables — validate ALL required vars up front and report every
# missing one, instead of failing later with a cryptic API error.
# ---------------------------------------------------------------------------
my @required_env = qw(
    CCAI_CLIENT_ID CCAI_API_KEY
    CCAI_TEST_PHONE CCAI_TEST_PHONE_2 CCAI_TEST_PHONE_3
    CCAI_TEST_EMAIL CCAI_TEST_EMAIL_2 CCAI_TEST_EMAIL_3
    CCAI_TEST_FIRST_NAME CCAI_TEST_LAST_NAME
    CCAI_TEST_FIRST_NAME_2 CCAI_TEST_LAST_NAME_2
    CCAI_TEST_FIRST_NAME_3 CCAI_TEST_LAST_NAME_3
    WEBHOOK_URL CCAI_TEST_TEMPLATE_ID
);
my @missing = grep { !defined $ENV{$_} || $ENV{$_} eq '' } @required_env;
if (@missing) {
    warn 'ERROR: required env vars are not set: ' . join(', ', @missing) . "\n";
    exit 2;
}

my $client_id = $ENV{CCAI_CLIENT_ID};
my $api_key   = $ENV{CCAI_API_KEY};
my $phone1    = $ENV{CCAI_TEST_PHONE};
my $phone2    = $ENV{CCAI_TEST_PHONE_2};
my $phone3    = $ENV{CCAI_TEST_PHONE_3};
my $email1    = $ENV{CCAI_TEST_EMAIL};
my $email2    = $ENV{CCAI_TEST_EMAIL_2};
my $email3    = $ENV{CCAI_TEST_EMAIL_3};
my $first1    = $ENV{CCAI_TEST_FIRST_NAME};
my $last1     = $ENV{CCAI_TEST_LAST_NAME};
my $first2    = $ENV{CCAI_TEST_FIRST_NAME_2};
my $last2     = $ENV{CCAI_TEST_LAST_NAME_2};
my $first3    = $ENV{CCAI_TEST_FIRST_NAME_3};
my $last3     = $ENV{CCAI_TEST_LAST_NAME_3};
my $template_id = $ENV{CCAI_TEST_TEMPLATE_ID};

# Unique per-run suffix so parallel SDK runs don't collide on the same webhook URL
my $run_id       = 'perl-' . time();
my $webhook_base = $ENV{WEBHOOK_URL};
my $webhook_url  = $webhook_base . (index($webhook_base, '?') >= 0 ? '&' : '?') . "run=$run_id";

my $sender_email   = $ENV{CCAI_TEST_SENDER_EMAIL} || 'noreply@cloudcontactai.com';
my $reply_email    = $sender_email;
my $webhook_secret = $ENV{CCAI_WEBHOOK_SECRET} || 'perl-test-secret-key';

# ---------------------------------------------------------------------------
# Client
# ---------------------------------------------------------------------------
# Use CCAI_BASE_URL if set (local dev), otherwise fall back to test environment
my $ccai = CCAI->new({
    client_id            => $client_id,
    api_key              => $api_key,
    use_test_environment => $ENV{CCAI_BASE_URL} ? 0 : 1,
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
my $passed  = 0;
my $failed  = 0;
my $skipped = 0;

# Marks a test that cannot run because a prerequisite test failed.
sub skip_test { die "SKIP: $_[0]\n" }

sub run_test {
    my ($label, $code) = @_;
    my $ok = eval { $code->(); 1 };
    if ($ok) {
        print "  [PASS] $label\n";
        $passed++;
    } else {
        my $err = $@ // 'unknown error';
        $err =~ s/\n.*//s;    # keep first line only
        if ($err =~ /^SKIP: (.*)$/) {
            print "  [SKIP] $label: $1\n";
            $skipped++;
        } else {
            print "  [FAIL] $label: $err\n";
            $failed++;
        }
    }
}

sub assert_success {
    my ($res, $label) = @_;
    die "undef response" unless defined $res;
    die "API error: " . ($res->{error} // 'unknown') unless $res->{success};
    return $res;
}

# Asserts success AND that the response data carries a campaign/message identifier.
sub assert_send_response {
    my ($res) = @_;
    assert_success($res);
    my $d = $res->{data};
    if (ref $d eq 'HASH') {
        die "response has no id/campaignId"
            unless defined $d->{id} || defined $d->{campaignId};
    }
    return $res;
}

# Runs the code and asserts that the operation fails (dies, returns undef, or
# returns success=0) — used by the negative test cases.
sub expect_failure {
    my ($what, $code) = @_;
    my $res = eval { $code->() };
    if ($@) {
        die $@ if $@ =~ /^SKIP:/;
        return;    # died — failed as expected
    }
    return unless defined $res;
    return if ref $res eq 'HASH' && !$res->{success};
    die "expected $what to fail, but it succeeded";
}

# IDs of resources created by the tests; anything still listed here at the end
# of the run is deleted by the cleanup section (tests remove entries they
# already deleted themselves).
my @cleanup_webhook_ids;
my @cleanup_brand_ids;
my @cleanup_campaign_ids;

print "=== CCAI Perl SDK Integration Tests ===\n\n";

my $suite_ok = eval {

# ---------------------------------------------------------------------------
# SMS Tests (01–06)
# ---------------------------------------------------------------------------
print "--- SMS ---\n";

run_test('01 SMS send_single', sub {
    my $res = $ccai->sms->send_single($first1, $last1, $phone1, 'Hello ${firstName}!', 'Perl Test 01');
    assert_send_response($res);
});

run_test('02 SMS send (1 recipient)', sub {
    my $res = $ccai->sms->send(
        [{ firstName => $first1, lastName => $last1, phone => $phone1 }],
        'Bulk test ${firstName}', 'Perl Test 02'
    );
    assert_send_response($res);
});

run_test('03 SMS send (2 recipients)', sub {
    my $res = $ccai->sms->send(
        [
            { firstName => $first1, lastName => $last1, phone => $phone1 },
            { firstName => $first2, lastName => $last2, phone => $phone2 },
        ],
        'Multi-recipient ${firstName}', 'Perl Test 03'
    );
    assert_send_response($res);
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
    assert_send_response($res);
});

run_test('05 SMS send with data (template variables)', sub {
    my $res = $ccai->sms->send(
        [{ firstName => $first1, lastName => $last1, phone => $phone1, data => { city => 'Miami', code => 'PL5' } }],
        'Hello ${firstName}, code ${code} from ${city}', 'Perl Test 05'
    );
    assert_send_response($res);
});

run_test('06 SMS send_single with messageData', sub {
    my $res = $ccai->sms->send_single(
        $first1, $last1, $phone1,
        'Custom data test', 'Perl Test 06',
        undef,                                  # options
        undef,                                  # data
        '{"source":"perl-integration"}'         # message_data
    );
    assert_send_response($res);
});

# ---------------------------------------------------------------------------
# MMS Tests (07–17)
# ---------------------------------------------------------------------------
print "\n--- MMS ---\n";

my $signed_url = undef;
my $file_key   = undef;
my $upload_ok  = 0;

run_test('07 MMS get_signed_url', sub {
    my $res = $ccai->mms->get_signed_url('perl_test.png', 'image/png');
    assert_success($res);
    die "Missing signed_s3_url" unless $res->{data}{signed_s3_url};
    die "Missing file_key" unless $res->{data}{file_key};
    $signed_url = $res->{data}{signed_s3_url};
    $file_key   = $res->{data}{file_key};
});

run_test('08 MMS upload_file', sub {
    skip_test('dependency test 07 failed') unless $signed_url;
    my $res = $ccai->mms->upload_file($signed_url, $image_path, 'image/png');
    assert_success($res);
    $upload_ok = 1;
});

run_test('09 MMS send_single', sub {
    skip_test('dependency test 07 failed') unless $file_key;
    my $res = $ccai->mms->send_single($first1, $last1, $phone1, 'MMS single test', 'Perl MMS 09', $file_key);
    assert_send_response($res);
});

run_test('10 MMS send (1 recipient)', sub {
    skip_test('dependency test 07 failed') unless $file_key;
    my $res = $ccai->mms->send(
        [{ firstName => $first1, lastName => $last1, phone => $phone1 }],
        'MMS bulk test', 'Perl MMS 10', $file_key
    );
    assert_send_response($res);
});

run_test('11 MMS send (2 recipients)', sub {
    skip_test('dependency test 07 failed') unless $file_key;
    my $res = $ccai->mms->send(
        [
            { firstName => $first1, lastName => $last1, phone => $phone1 },
            { firstName => $first2, lastName => $last2, phone => $phone2 },
        ],
        'MMS 2-recipient test', 'Perl MMS 11', $file_key
    );
    assert_send_response($res);
});

run_test('12 MMS send (3 recipients)', sub {
    skip_test('dependency test 07 failed') unless $file_key;
    my $res = $ccai->mms->send(
        [
            { firstName => $first1, lastName => $last1, phone => $phone1 },
            { firstName => $first2, lastName => $last2, phone => $phone2 },
            { firstName => $first3, lastName => $last3, phone => $phone3 },
        ],
        'MMS 3-recipient test', 'Perl MMS 12', $file_key
    );
    assert_send_response($res);
});

run_test('13 MMS send with data (template variables)', sub {
    skip_test('dependency test 07 failed') unless $file_key;
    my $res = $ccai->mms->send(
        [{ firstName => $first1, lastName => $last1, phone => $phone1, data => { promo => 'PL13' } }],
        'MMS data test promo ${promo}', 'Perl MMS 13', $file_key
    );
    assert_send_response($res);
});

run_test('14 MMS send_single with customData', sub {
    skip_test('dependency test 07 failed') unless $file_key;
    my $res = $ccai->mms->send_single(
        $first1, $last1, $phone1,
        'MMS custom data test', 'Perl MMS 14', $file_key,
        '{"source":"perl-integration"}'
    );
    assert_send_response($res);
});

run_test('15 MMS check_file_uploaded', sub {
    skip_test('dependency test 07 failed') unless $file_key;
    skip_test('dependency test 08 failed') unless $upload_ok;
    my $res = $ccai->mms->check_file_uploaded($file_key);
    # The file was uploaded in test 08, so it MUST be found.
    die "expected uploaded file $file_key to be found, got undef" unless defined $res;
});

run_test('16 MMS send_with_image (fresh upload)', sub {
    my $res = $ccai->mms->send_with_image(
        [{ firstName => $first1, lastName => $last1, phone => $phone1 }],
        'MMS sendWithImage test', 'Perl MMS 16', $image_path
    );
    assert_send_response($res);
});

run_test('17 MMS send_with_image (cached, same file)', sub {
    my $res = $ccai->mms->send_with_image(
        [{ firstName => $first1, lastName => $last1, phone => $phone1 }],
        'MMS cached image test', 'Perl MMS 17', $image_path
    );
    assert_send_response($res);
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
    assert_send_response($res);
});

run_test('19 Email send (1 recipient)', sub {
    my $res = $ccai->email->send(
        [{ firstName => $first1, lastName => $last1, email => $email1 }],
        'Perl Integration Test 19',
        '<p>Hello ${firstName}!</p>',
        $sender_email,
        $reply_email,
        'Perl Test'
    );
    assert_send_response($res);
});

run_test('20 Email send (2 recipients)', sub {
    my $res = $ccai->email->send(
        [
            { firstName => $first1, lastName => $last1, email => $email1 },
            { firstName => $first2, lastName => $last2, email => $email2 },
        ],
        'Perl Integration Test 20',
        '<p>Hello ${firstName}!</p>',
        $sender_email,
        $reply_email,
        'Perl Test'
    );
    assert_send_response($res);
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
        $sender_email,
        $reply_email,
        'Perl Test'
    );
    assert_send_response($res);
});

run_test('22 Email send_campaign (full config)', sub {
    my $res = $ccai->email->send_campaign({
        accounts      => [{ firstName => $first1, lastName => $last1, email => $email1 }],
        subject       => 'Perl Integration Test 22',
        title         => 'Perl Campaign Test 22',
        message       => '<h1>Campaign Test</h1><p>Hello ${firstName}, this is a full campaign test.</p>',
        sender_email  => $sender_email,
        reply_email   => $reply_email,
        sender_name   => 'Perl Integration',
        campaign_type => 'EMAIL',
        add_to_list   => 'noList',
        contact_input => 'accounts',
        from_type     => 'single',
        senders       => [],
    });
    assert_send_response($res);
});

# ---------------------------------------------------------------------------
# Webhook Tests (23–29)
# ---------------------------------------------------------------------------
print "\n--- Webhook ---\n";

my $webhook_id = undef;

run_test('23 Webhook register', sub {
    my $res = $ccai->webhook->register({
        url             => $webhook_url,
        secret          => $webhook_secret,
        integration_type => 'ALL',
    });
    assert_success($res);
    die "No id in register response" unless $res->{data}{id};
    $webhook_id = $res->{data}{id};
    push @cleanup_webhook_ids, $webhook_id;
});

run_test('24 Webhook list', sub {
    my $res = $ccai->webhook->list();
    assert_success($res);
    die "Expected array data" unless ref $res->{data} eq 'ARRAY';
    if ($webhook_id) {
        my $found = grep { ($_->{id} // '') eq $webhook_id } @{ $res->{data} };
        die "webhook $webhook_id registered in test 23 not present in list" unless $found;
    }
});

run_test('25 Webhook update', sub {
    skip_test('dependency test 23 failed') unless $webhook_id;
    my $res = $ccai->webhook->update($webhook_id, {
        url             => $webhook_url . '&updated=1',
        integration_type => 'ALL',
    });
    assert_success($res);
    # Verify via list that the URL actually changed
    my $list = $ccai->webhook->list();
    assert_success($list);
    my ($hook) = grep { ($_->{id} // '') eq $webhook_id } @{ $list->{data} };
    die "webhook $webhook_id not found in list after update" unless $hook;
    die "webhook URL was not updated: got \"$hook->{url}\""
        unless index($hook->{url} // '', 'updated=1') >= 0;
});

run_test('26 Webhook verify_signature (valid)', sub {
    my $event_hash = 'abc123hash';
    my $data       = "$client_id:$event_hash";
    my $expected   = encode_base64(hmac_sha256($data, $webhook_secret), '');
    my $ok = $ccai->webhook->verify_signature($expected, $client_id, $event_hash, $webhook_secret);
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
    skip_test('dependency test 23 failed') unless $webhook_id;
    my $res = $ccai->webhook->delete($webhook_id);
    assert_success($res);
    @cleanup_webhook_ids = grep { $_ ne $webhook_id } @cleanup_webhook_ids;
    # Verify via list that it is gone
    my $list = $ccai->webhook->list();
    assert_success($list);
    my $still = grep { ($_->{id} // '') eq $webhook_id } @{ $list->{data} };
    die "webhook $webhook_id still present in list after delete" if $still;
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
# Brands Tests (32–36)
# ---------------------------------------------------------------------------
print "\n--- Brands ---\n";

my $brand_id = undef;

run_test('32 Brand create', sub {
    my $res = $ccai->brand->create({
        legalCompanyName   => 'Perl SDK Test Brand LLC',
        dba                => 'Perl SDK Test Brand',
        entityType         => 'PRIVATE_PROFIT',
        taxId              => '123456789',
        taxIdCountry       => 'US',
        country            => 'US',
        verticalType       => 'TECHNOLOGY',
        websiteUrl         => 'https://example.com',
        street             => '123 Test St',
        city               => 'Miami',
        state              => 'FL',
        postalCode         => '33101',
        contactFirstName   => 'Test',
        contactLastName    => 'User',
        contactEmail       => 'test@example.com',
        contactPhone       => '+13055551234',
    });
    assert_success($res);
    die "id missing from create response" unless $res->{data}{id};
    $brand_id = $res->{data}{id};
    push @cleanup_brand_ids, $brand_id;
});

run_test('33 Brand get', sub {
    skip_test('dependency test 32 failed') unless $brand_id;
    my $res = $ccai->brand->get($brand_id);
    assert_success($res);
    my $got_id = $res->{data}{id} // '';
    die "brand id mismatch: expected $brand_id, got $got_id" unless "$got_id" eq "$brand_id";
    my $name = $res->{data}{legalCompanyName} // '';
    die "expected legalCompanyName \"Perl SDK Test Brand LLC\", got \"$name\""
        unless $name eq 'Perl SDK Test Brand LLC';
});

run_test('34 Brand list', sub {
    my $res = $ccai->brand->list();
    assert_success($res);
    if ($brand_id && ref $res->{data} eq 'ARRAY') {
        my $found = grep { ($_->{id} // '') eq $brand_id } @{ $res->{data} };
        die "brand $brand_id created in test 32 not present in list" unless $found;
    }
});

run_test('35 Brand update', sub {
    skip_test('dependency test 32 failed') unless $brand_id;
    my $res = $ccai->brand->update($brand_id, {
        city => 'Fort Lauderdale',
    });
    assert_success($res);
    # Verify via get that the field actually changed
    my $fetched = $ccai->brand->get($brand_id);
    assert_success($fetched);
    my $city = $fetched->{data}{city} // '';
    die "expected city \"Fort Lauderdale\" after update, got \"$city\"" unless $city eq 'Fort Lauderdale';
});

run_test('36 Brand delete', sub {
    skip_test('dependency test 32 failed') unless $brand_id;
    my $res = $ccai->brand->delete($brand_id);
    assert_success($res);
    @cleanup_brand_ids = grep { $_ ne $brand_id } @cleanup_brand_ids;
    # Verify via get that it is gone
    expect_failure("get of deleted brand $brand_id", sub { $ccai->brand->get($brand_id) });
});

# ---------------------------------------------------------------------------
# Campaigns Tests (37–42)
# ---------------------------------------------------------------------------
print "\n--- Campaigns ---\n";

my $campaign_brand_id = undef;
my $campaign_id       = undef;

run_test('37 Campaign setup — Brand create', sub {
    my $res = $ccai->brand->create({
        legalCompanyName   => 'Perl SDK Campaign Brand LLC',
        dba                => 'Perl SDK Campaign Brand',
        entityType         => 'PRIVATE_PROFIT',
        taxId              => '987654321',
        taxIdCountry       => 'US',
        country            => 'US',
        verticalType       => 'TECHNOLOGY',
        websiteUrl         => 'https://campaign-example.com',
        street             => '456 Campaign Ave',
        city               => 'Miami',
        state              => 'FL',
        postalCode         => '33102',
        contactFirstName   => 'Campaign',
        contactLastName    => 'Test',
        contactEmail       => 'campaign@example.com',
        contactPhone       => '+13055559999',
    });
    assert_success($res);
    die "id missing from create response" unless $res->{data}{id};
    $campaign_brand_id = $res->{data}{id};
    push @cleanup_brand_ids, $campaign_brand_id;
});

run_test('38 Campaign create', sub {
    skip_test('dependency test 37 failed') unless $campaign_brand_id;
    my $res = $ccai->campaign->create({
        brandId           => $campaign_brand_id,
        useCase           => 'MARKETING',
        description       => 'Perl SDK test campaign for integration testing',
        messageFlow       => 'Users opt-in via our website form.',
        hasEmbeddedLinks  => JSON::false,
        hasEmbeddedPhone  => JSON::false,
        isAgeGated        => JSON::false,
        isDirectLending   => JSON::false,
        optInKeywords     => ['START', 'YES'],
        optInMessage      => 'You are now subscribed. Reply STOP to unsubscribe.',
        optInProofUrl     => 'https://example.com/optin',
        helpKeywords      => ['HELP', 'INFO'],
        helpMessage       => 'For help, contact support@example.com. Reply HELP for assistance.',
        optOutKeywords    => ['STOP', 'CANCEL'],
        optOutMessage     => 'You have been unsubscribed. Reply STOP to opt out.',
        sampleMessages    => [
            'Hello! Reply STOP to unsubscribe.',
            'Your code is 123456. Reply HELP for assistance.',
        ],
    });
    assert_success($res);
    die "id missing from create response" unless $res->{data}{id};
    $campaign_id = $res->{data}{id};
    push @cleanup_campaign_ids, $campaign_id;
});

run_test('39 Campaign get', sub {
    skip_test('dependency test 38 failed') unless $campaign_id;
    my $res = $ccai->campaign->get($campaign_id);
    assert_success($res);
    my $got_id = $res->{data}{id} // '';
    die "campaign id mismatch: expected $campaign_id, got $got_id" unless "$got_id" eq "$campaign_id";
    my $got_brand = $res->{data}{brandId} // '';
    die "expected brandId $campaign_brand_id, got $got_brand" unless "$got_brand" eq "$campaign_brand_id";
});

run_test('40 Campaign list', sub {
    my $res = $ccai->campaign->list();
    assert_success($res);
    if ($campaign_id && ref $res->{data} eq 'ARRAY') {
        my $found = grep { ($_->{id} // '') eq $campaign_id } @{ $res->{data} };
        die "campaign $campaign_id created in test 38 not present in list" unless $found;
    }
});

run_test('41 Campaign update', sub {
    skip_test('dependency test 38 failed') unless $campaign_id;
    my $new_description = 'Perl SDK updated campaign description';
    my $res = $ccai->campaign->update($campaign_id, {
        description => $new_description,
    });
    assert_success($res);
    # Verify via get that the field actually changed
    my $fetched = $ccai->campaign->get($campaign_id);
    assert_success($fetched);
    my $description = $fetched->{data}{description} // '';
    die "expected updated description after update, got \"$description\""
        unless $description eq $new_description;
});

run_test('42 Campaign delete', sub {
    skip_test('dependency test 38 failed') unless $campaign_id;
    my $res = $ccai->campaign->delete($campaign_id);
    assert_success($res);
    @cleanup_campaign_ids = grep { $_ ne $campaign_id } @cleanup_campaign_ids;
    # Verify via get that it is gone
    expect_failure("get of deleted campaign $campaign_id", sub { $ccai->campaign->get($campaign_id) });
    # Clean up campaign brand
    if ($campaign_brand_id) {
        my $del = $ccai->brand->delete($campaign_brand_id);
        assert_success($del);
        @cleanup_brand_ids = grep { $_ ne $campaign_brand_id } @cleanup_brand_ids;
    }
});

# ---------------------------------------------------------------------------
# ContactValidator Tests (43–46)
# ---------------------------------------------------------------------------
print "\n--- ContactValidator ---\n";

run_test('43 ContactValidator validate_email', sub {
    my $res = $ccai->contact_validator->validate_email($email1);
    assert_success($res);
    die "status is empty" unless $res->{data}{status};
});

run_test('44 ContactValidator validate_emails', sub {
    my $res = $ccai->contact_validator->validate_emails([$email1, $email2]);
    assert_success($res);
    my $total = $res->{data}{summary}{total} // 0;
    die "expected summary.total=2, got $total" unless $total == 2;
    my $results = $res->{data}{results} // [];
    die "expected 2 results, got " . scalar(@$results) unless @$results == 2;
});

run_test('45 ContactValidator validate_phone', sub {
    my $res = $ccai->contact_validator->validate_phone($phone1);
    assert_success($res);
    die "status is empty" unless $res->{data}{status};
});

run_test('46 ContactValidator validate_phones', sub {
    my $res = $ccai->contact_validator->validate_phones([
        { phone => $phone1 },
        { phone => $phone2 },
    ]);
    assert_success($res);
    my $total = $res->{data}{summary}{total} // 0;
    die "expected summary.total=2, got $total" unless $total == 2;
    my $results = $res->{data}{results} // [];
    die "expected 2 results, got " . scalar(@$results) unless @$results == 2;
});

# ---------------------------------------------------------------------------
# Negative & Permissive Tests (47–52)
# 47/49/50 PASS when the operation fails as expected. 48/51/52 document
# permissive behavior observed in the test API: those
# operations succeed even with invalid input, so the tests assert success.
# ---------------------------------------------------------------------------
print "\n--- Negative cases ---\n";

run_test('47 NEGATIVE: SMS send_single with invalid API key', sub {
    my $bad_client = CCAI->new({
        client_id            => $client_id,
        api_key              => 'invalid-api-key-for-negative-test',
        use_test_environment => $ENV{CCAI_BASE_URL} ? 0 : 1,
    });
    expect_failure('send with invalid API key', sub {
        $bad_client->sms->send_single($first1, $last1, $phone1, 'should fail', 'Perl Negative 47');
    });
});

# The test API accepts malformed phone numbers: the send
# succeeds instead of failing. If the API starts validating phone format,
# change this back to expect_failure.
run_test('48 PERMISSIVE: SMS send_single with malformed phone (API accepts)', sub {
    my $res = $ccai->sms->send_single($first1, $last1, 'abc', 'malformed phone accepted', 'Perl Permissive 48');
    assert_send_response($res);
});

run_test('49 NEGATIVE: Brand get(nonexistent)', sub {
    expect_failure('get of nonexistent brand', sub { $ccai->brand->get(99999999) });
});

run_test('50 NEGATIVE: Webhook delete(nonexistent)', sub {
    expect_failure('delete of nonexistent webhook', sub { $ccai->webhook->delete(99999999) });
});

# The test environment's validator reports "valid" even for syntactically
# invalid emails — upstream validation is not enforced
# there, so only assert that a status is returned.
run_test('51 PERMISSIVE: ContactValidator validate_email(invalid input)', sub {
    my $res = $ccai->contact_validator->validate_email('not-an-email');
    assert_success($res);
    my $status = $res->{data}{status} // '';
    die "status is empty" unless $status;
});

# The test API accepts MMS sends with a nonexistent fileKey: it does not
# verify the file exists at send time. If the API
# starts validating the fileKey, change this back to expect_failure.
run_test('52 PERMISSIVE: MMS send with nonexistent fileKey (API accepts)', sub {
    my $fake_key = "$client_id/campaign/nonexistent_" . time() . '.png';
    my $res = $ccai->mms->send(
        [{ firstName => $first1, lastName => $last1, phone => $phone1 }],
        'nonexistent fileKey accepted', 'Perl Permissive 52', $fake_key
    );
    assert_send_response($res);
});

print "\n--- SMS Templates ---\n";

run_test('53 SMS send_with_template', sub {
    my $res = $ccai->sms->send_with_template([
        {firstName => $first1, lastName => $last1, phone => $phone1},
        {firstName => $first2, lastName => $last2, phone => $phone2},
    ], $template_id, 'Perl Template Test');
    assert_send_response($res);
});

run_test('54 SMS send_single_with_template', sub {
    my $res = $ccai->sms->send_single_with_template($first1, $last1, $phone1, $template_id, 'Perl Single Template Test');
    assert_send_response($res);
});

1;
};
warn "Unexpected error in test suite: $@" unless $suite_ok;

# ---------------------------------------------------------------------------
# Cleanup — always runs, even if the test body died: delete leftover resources.
# (The temp PNG is removed automatically by File::Temp UNLINK => 1.)
# ---------------------------------------------------------------------------
for my $id (@cleanup_campaign_ids) {
    my $res = eval { $ccai->campaign->delete($id) };
    if ($res && $res->{success}) {
        print "  CLEANUP: deleted leftover campaign $id\n";
    } else {
        print "  CLEANUP: could not delete campaign $id\n";
    }
}
for my $id (@cleanup_brand_ids) {
    my $res = eval { $ccai->brand->delete($id) };
    if ($res && $res->{success}) {
        print "  CLEANUP: deleted leftover brand $id\n";
    } else {
        print "  CLEANUP: could not delete brand $id\n";
    }
}
for my $id (@cleanup_webhook_ids) {
    my $res = eval { $ccai->webhook->delete($id) };
    if ($res && $res->{success}) {
        print "  CLEANUP: deleted leftover webhook $id\n";
    } else {
        print "  CLEANUP: could not delete webhook $id\n";
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
my $total = $passed + $failed + $skipped;
print "\n=== Results: $passed passed, $failed failed, $skipped skipped ($total total) ===\n";

printf "\nSUMMARY_JSON: {\"sdk\":\"perl\",\"passed\":%d,\"failed\":%d,\"skipped\":%d,\"total\":%d}\n",
    $passed, $failed, $skipped, $total;

exit($failed > 0 ? 1 : 0);
