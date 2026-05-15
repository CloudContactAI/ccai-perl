# CCAI Perl Client v1.6.0

A Perl client for the [CloudContactAI](https://cloudcontactai.com) API that allows you to easily send SMS and MMS messages, send email campaigns, manage webhooks, and manage contact opt-out preferences.

## What's New in v1.5.0

### 🌐 Test Environment Support
- **`use_test_environment` config option**: Automatically switches all API URLs (core, email, auth, files) to test environment domains
- **`files_url` support**: New files API URL config, used by MMS for image uploads
- **`is_test_environment()` / `get_files_url()` getters**

### 📸 MMS Overhaul
- **MD5-based image deduplication**: Images are hashed and checked before uploading, avoiding redundant uploads
- **Auto content-type detection**: Inferred from file extension (jpg, jpeg, png, gif)
- **`send_single()` method**: Convenience method for single-recipient MMS
- **`senderPhone` support**: Optional sender phone parameter on `send` and `send_with_image`
- **Test-environment aware**: Uses `files_url` from config instead of hardcoded URL

### 🔄 Enhanced Webhook Support
- **Unified Event Handler**: New `handle_event()` method processes all webhook event types with a single callback
- **Support for 5 Event Types**: `message.sent`, `message.incoming`, `message.excluded`, `message.error.carrier`, `message.error.cloudcontact`
- **CustomData Support**: Pass custom data with SMS messages that will be included in webhook events
- **Backward Compatibility**: Existing `parse_event()` method still supported

## Requirements

- Perl 5.16.0 or higher
- Required CPAN modules (see Installation)

## Installation

```bash
git clone https://github.com/cloudcontactai/ccai-perl.git
cd ccai-perl
cpanm --installdeps .

# Set up your credentials
cp .env.example .env
# Edit .env and add your CCAI credentials

# Test with examples
cd examples
perl sms_send.pl
```

**Note:** The SSL modules (Mozilla::CA, LWP::Protocol::https, IO::Socket::SSL) are required for secure HTTPS communication with the CCAI API. The client automatically configures SSL certificates using Mozilla::CA.

## Configuration

### Environment Variables

```bash
cp .env.example .env
```

Edit `.env` with your credentials:

```bash
CCAI_CLIENT_ID=your-client-id-here
CCAI_API_KEY=your-api-key-here

# Optional: Suppress LWP Content-Length warnings
CCAI_SUPPRESS_WARNINGS=1
```

Use in your code:

```perl
use CCAI;
use CCAI::EnvLoader;

CCAI::EnvLoader->load();
my ($client_id, $api_key) = CCAI::EnvLoader->get_ccai_credentials();

my $ccai = CCAI->new({
    client_id => $client_id,
    api_key   => $api_key
});
```

### Direct Configuration

```perl
my $ccai = CCAI->new({
    client_id => 'YOUR-CLIENT-ID',
    api_key   => 'API-KEY-TOKEN'
});
```

### Test Environment

Set `use_test_environment => 1` to automatically switch all API URLs to test environment domains:

```perl
my $ccai = CCAI->new({
    client_id            => $client_id,
    api_key              => $api_key,
    use_test_environment => 1,
});
```

| URL | Production | Test |
|-----|-----------|------|
| base_url | `core.cloudcontactai.com` | `core-test-cloudcontactai.allcode.com` |
| email_url | `email-campaigns.cloudcontactai.com` | `email-campaigns-test-cloudcontactai.allcode.com` |
| auth_url | `auth.cloudcontactai.com` | `auth-test-cloudcontactai.allcode.com` |
| files_url | `files.cloudcontactai.com` | `files-test-cloudcontactai.allcode.com` |

You can also override individual URLs:

```perl
my $ccai = CCAI->new({
    client_id            => $client_id,
    api_key              => $api_key,
    use_test_environment => 1,
    base_url             => 'https://custom-core.example.com/api',  # overrides test default
});
```

## Usage

### SMS

```perl
my $ccai = CCAI->new({
    client_id => 'YOUR-CLIENT-ID',
    api_key   => 'API-KEY-TOKEN'
});

# Send SMS to multiple recipients
my @accounts = (
    {
        firstName => "John",
        lastName  => "Doe",
        phone     => "+15551234567"
    },
    {
        firstName => "Jane",
        lastName  => "Smith",
        phone     => "+15559876543"
    }
);

my $response = $ccai->sms->send(
    \@accounts,
    "Hello \${firstName} \${lastName}, this is a test message!",
    "Test Campaign"
);

if ($response->{success}) {
    print "SMS sent successfully!\n";
} else {
    print "Error: " . $response->{error} . "\n";
}

# Send SMS to a single recipient
my $single = $ccai->sms->send_single(
    "Jane", "Smith", "+15559876543",
    "Hi \${firstName}, thanks for your interest!",
    "Single Message Test"
);

# Send SMS with customData (included in webhook events for tracking)
my @accounts_with_data = (
    {
        firstName  => "John",
        lastName   => "Doe",
        phone      => "+15551234567",
        customData => {
            order_id      => "ORD-12345",
            customer_type => "premium"
        }
    }
);

$ccai->sms->send(\@accounts_with_data, "Your order is ready!", "Order Notification");
```

### MMS

The MMS service automatically handles image uploading with MD5-based deduplication and auto-detects content type from the file extension (jpg, jpeg, png, gif).

```perl
# Send MMS to multiple recipients (auto-uploads image, deduplicates via MD5)
my @accounts = (
    { firstName => "John", lastName => "Doe", phone => "+15551234567" },
    { firstName => "Jane", lastName => "Smith", phone => "+15559876543" }
);

my $response = $ccai->mms->send_with_image(
    \@accounts,
    "Hello \${firstName}, check out this image!",
    "MMS Campaign",
    "path/to/image.jpg"
);

# Send MMS to a single recipient (shorthand)
my $single = $ccai->mms->send_single(
    "John", "Doe", "+15551234567",
    "Hello \${firstName}!",
    "Single MMS Test",
    "path/to/image.png"
);

# Send MMS with a specific sender phone
$ccai->mms->send_with_image(
    \@accounts,
    "Hello \${firstName}!",
    "MMS Campaign",
    "path/to/image.jpg",
    "+15550001111"  # sender phone
);
```

### Email

```perl
# Send a single email
my $response = $ccai->email->send_single(
    "John",                                    # First name
    "Doe",                                     # Last name
    "john@example.com",                        # Email address
    "Welcome to Our Service",                  # Subject
    "<p>Hello \${firstName},</p><p>Thank you for signing up!</p>",
    "noreply@yourcompany.com",                 # Sender email
    "support@yourcompany.com",                 # Reply-to email
    "Your Company",                            # Sender name
    "Welcome Email"                            # Campaign title
);

# Send an email campaign to multiple recipients
my $campaign = {
    subject      => "Monthly Newsletter",
    title        => "Newsletter",
    message      => "<h1>Newsletter</h1><p>Hello \${firstName},</p>",
    sender_email => "newsletter@yourcompany.com",
    reply_email  => "support@yourcompany.com",
    sender_name  => "Your Company Newsletter",
    accounts     => [
        { firstName => "John", lastName => "Doe", email => "john@example.com" },
        { firstName => "Jane", lastName => "Smith", email => "jane@example.com" }
    ],
    campaign_type => "EMAIL",
    add_to_list   => "noList",
    contact_input => "accounts",
    from_type     => "single",
    senders       => []
};

my $campaign_response = $ccai->email->send_campaign($campaign);
```

### Contact

Manage opt-out preferences for contacts.

```perl
my $ccai = CCAI->new({
    client_id => 'YOUR-CLIENT-ID',
    api_key   => 'API-KEY-TOKEN'
});

# Opt a contact out of text messages (by phone number)
my $result = $ccai->contact->set_do_not_text(
    do_not_text => 1,
    phone       => '+15551234567'
);
print "Opted out: $result->{phone}\n" if $result->{success};

# Opt a contact back in
$ccai->contact->set_do_not_text(
    do_not_text => 0,
    phone       => '+15551234567'
);

# Opt out by contact_id
$ccai->contact->set_do_not_text(
    do_not_text => 1,
    contact_id  => 'contact-abc-123'
);
```

### Contact Validator

Validate email addresses and phone numbers.

> Bulk endpoints accept up to 50 contacts per request and are processed server-side in chunks.

```perl
my $ccai = CCAI->new({
    client_id => 'YOUR-CLIENT-ID',
    api_key   => 'API-KEY-TOKEN'
});

# Validate a single email
my $email_result = $ccai->contact_validator->validate_email('user@example.com');
if ($email_result->{success}) {
    print "Status: " . $email_result->{data}{status} . "\n"; # "valid" | "invalid" | "risky"
}

# Validate multiple emails (up to 50, processed server-side in chunks)
my $bulk_emails = $ccai->contact_validator->validate_emails([
    'user@example.com',
    'bad@invalid.xyz'
]);
if ($bulk_emails->{success}) {
    print "Total: " . $bulk_emails->{data}{summary}{total} . "\n"; # 2
    print "Valid: " . $bulk_emails->{data}{summary}{valid} . "\n"; # 1
}

# Validate a single phone number
my $phone_result = $ccai->contact_validator->validate_phone('+15551234567', { country_code => 'US' });
if ($phone_result->{success}) {
    print "Status: " . $phone_result->{data}{status} . "\n"; # "valid" | "invalid" | "landline"
}

# Validate multiple phone numbers (up to 50, processed server-side in chunks)
my $bulk_phones = $ccai->contact_validator->validate_phones([
    { phone => '+15551234567' },
    { phone => '+15559876543', countryCode => 'US' }
]);
if ($bulk_phones->{success}) {
    print "Landline: " . $bulk_phones->{data}{summary}{landline} . "\n"; # 1
}
```

### Webhooks

#### Register a Webhook

```perl
use CCAI;
use CCAI::Webhook;  # Import webhook types/constants

# Example 1: Register with auto-generated secret
# WebhookConfig: { url => Str, secret => Str|Undef, events => ArrayRef|Undef }
# Returns: { success => Bool, data => { id => Int, url => Str, secretKey => Str } }
my $webhook_config = {
    url => "https://example.com/webhook"
    # secret not provided - server will auto-generate and return it
};

my $webhook_response = $ccai->webhook->register($webhook_config);

if ($webhook_response->{success}) {
    my $webhook_id = $webhook_response->{data}->{id};           # Int
    my $webhook_url = $webhook_response->{data}->{url};         # Str
    my $webhook_secret = $webhook_response->{data}->{secretKey};  # Str
    
    print "Webhook registered with ID: $webhook_id\n";
    print "Auto-generated Secret: $webhook_secret\n";
}

# Example 2: Register with custom secret and event types
# Events array should contain event type constants from CCAI::Webhook
my $webhook_config_custom = {
    url    => "https://example.com/webhook-v2",
    secret => "my-custom-secret-key",
    # Optional: specify event types
    events => [
        CCAI::Webhook::EventType::MESSAGE_SENT,
        CCAI::Webhook::EventType::MESSAGE_RECEIVED
    ]
};

my $webhook_custom = $ccai->webhook->register($webhook_config_custom);
if ($webhook_custom->{success}) {
    print "Webhook with custom secret registered: " 
        . $webhook_custom->{data}->{id} . "\n";
}

# List all webhooks
# Returns: { success => Bool, data => ArrayRef[WebhookResponse] }
my $list_response = $ccai->webhook->list();
if ($list_response->{success}) {
    my $webhooks = $list_response->{data};  # ArrayRef[HashRef]
    print "Found " . scalar(@{$webhooks}) . " webhooks\n";
    
    foreach my $webhook (@{$webhooks}) {
        my $id = $webhook->{id};         # Int
        my $url = $webhook->{url};       # Str
        my $secret = $webhook->{secretKey};  # Str (can be undef if user didn't set one)
        
        print "  - ID: $id, URL: $url\n";
    }
}

# Update a webhook
# Parameters: (webhookId: Int, config: WebhookConfig)
# Returns: { success => Bool, data => WebhookResponse }
my $webhook_id = $webhook_response->{data}->{id};  # Int
my $update_config = {
    url    => "https://example.com/webhook-updated",
    secret => "updated-secret-key"
};

my $update_response = $ccai->webhook->update($webhook_id, $update_config);
if ($update_response->{success}) {
    print "Webhook updated successfully\n";
}

# Delete a webhook
# Parameters: webhookId => Int
# Returns: { success => Bool, message => Str }
my $delete_response = $ccai->webhook->delete($webhook_id);
if ($delete_response->{success}) {
    print "Webhook deleted: " . $delete_response->{message} . "\n";
} else {
    print "Failed to delete webhook: " . $delete_response->{message} . "\n";
}
```

#### Unified Event Handler (Recommended)

```perl
# Process webhook events with unified handler
# Parameters:
#   $json    => Str (JSON webhook payload)
#   $signature => Str (webhook signature from X-CCAI-Signature header)
#   $secret  => Str (webhook secret for verification)
# Returns: Bool (true if event was processed, false if signature invalid)
sub process_webhook_event {
    my ($json, $signature, $secret) = @_;

    # Parse the webhook payload to get client_id and event_hash
    my $payload = JSON::decode_json($json);
    
    my $client_id = $ENV{CCAI_CLIENT_ID};   # Str
    my $event_hash = $payload->{eventHash};  # Str
    my $event_type = $payload->{eventType};  # Str: 'message.sent', 'message.received', etc.
    my $event_data = $payload->{data};       # HashRef with event details

    # Verify signature using 4-parameter format: (signature, clientId, eventHash, secret)
    # Returns: Bool - true if signature matches, false otherwise
    return unless $ccai->webhook->verify_signature(
        $signature,   # Str from X-CCAI-Signature header
        $client_id,   # Str from CCAI_CLIENT_ID env var
        $event_hash,  # Str from webhook payload
        $secret       # Str from webhook config
    );

    # Handle the event
    $ccai->webhook->handle_event($json, sub {
        my ($event_type, $data) = @_;

        if ($event_type eq 'message.sent') {
            print "Message delivered to $data->{To}\n";
        } elsif ($event_type eq 'message.incoming') {
            print "Reply from $data->{From}: $data->{Message}\n";
        } elsif ($event_type eq 'message.excluded') {
            print "Message excluded: $data->{ExcludedReason}\n";
        } elsif ($event_type eq 'message.error.carrier') {
            print "Carrier error $data->{ErrorCode}: $data->{ErrorMessage}\n";
        } elsif ($event_type eq 'message.error.cloudcontact') {
            print "System error $data->{ErrorCode}: $data->{ErrorMessage}\n";
        }

        if ($data->{CustomData} && $data->{CustomData} ne '') {
            print "Custom Data: $data->{CustomData}\n";
        }
    });
}
```

#### Supported Event Types

| Event | Description |
|-------|-------------|
| `message.sent` | Message delivered. Includes `TotalPrice`, `Segments`, campaign details. |
| `message.incoming` | Reply received from recipient. |
| `message.excluded` | Message excluded (duplicate phone, invalid format, etc.). |
| `message.error.carrier` | Carrier-level delivery failure (error codes 30008, 30007, etc.). |
| `message.error.cloudcontact` | System error (CCAI-001, CCAI-002, etc.). |

#### Legacy Event Processing

```perl
my $event = $ccai->webhook->parse_event($json);
if ($event && $event->{type} eq "message.sent") {
    print "Message sent to: $event->{To}\n";
}
```

## Project Structure

```
lib/
  CCAI.pm              # Main client class
  CCAI/SMS.pm          # SMS service
  CCAI/MMS.pm          # MMS service
  CCAI/Email.pm        # Email service
  CCAI/Contact.pm      # Contact service (opt-out)
  CCAI/Webhook.pm      # Webhook service
  CCAI/EnvLoader.pm    # Environment variable loader
examples/              # Usage examples
t/                     # Tests
```

## Testing

```bash
# Run all tests
prove -l t/

# Run with verbose output
prove -lv t/
```

## Error Handling

All methods return a hash reference:

```perl
# Success
{ success => 1, data => { ... } }

# Error
{ success => 0, error => "Error message" }
```

## Template Variables

Messages support automatic variable substitution:

- `${firstName}` - Recipient's first name
- `${lastName}` - Recipient's last name

## Warning Suppression

LWP may show harmless "Content-Length header value was wrong, fixed" warnings. Suppress them by setting `CCAI_SUPPRESS_WARNINGS=1` in your `.env` file, or call `$ccai->suppress_lwp_warnings()` after creating the client.

## License

MIT © 2026 CloudContactAI LLC
