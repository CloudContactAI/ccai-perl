# CCAI Perl Client v1.3.0

A Perl client for the [CloudContactAI](https://cloudcontactai.com) API that allows you to easily send SMS and MMS messages, send email campaigns, and manage webhooks.

## What's New in v1.3.0

- **CustomData Support**: Pass custom data with SMS messages that will be included in webhook events
- Enhanced webhook event handling with custom data correlation
- Improved business process integration capabilities

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

# Verify SSL configuration
perl verify_ssl.pl

# Test with examples
perl -Ilib examples/sms_send.pl
```

Install required dependencies:

```bash
# Using cpanm (recommended) - installs all dependencies including SSL support
cpanm --installdeps .

# Or install individual modules
cpanm LWP::UserAgent JSON HTTP::Request::Common File::Basename MIME::Base64 Mozilla::CA LWP::Protocol::https IO::Socket::SSL Digest::SHA

# Or using cpan
cpan LWP::UserAgent JSON HTTP::Request::Common File::Basename MIME::Base64 Mozilla::CA LWP::Protocol::https IO::Socket::SSL Digest::SHA
```

**SSL Configuration**: The client automatically configures SSL certificates. If you encounter SSL issues, run:
```bash
perl verify_ssl.pl
```

# Or install all dependencies from cpanfile
```
cpanm --installdeps .
```

**Note:** The SSL modules (Mozilla::CA, LWP::Protocol::https, IO::Socket::SSL) are required for secure HTTPS communication with the CCAI API.

## Configuration

### Environment Variables

The CCAI Perl client supports loading credentials from environment variables using a `.env` file:

1. **Copy the example file:**
   ```bash
   cp .env.example .env
   ```

2. **Edit `.env` with your credentials:**
   ```bash
   # CCAI API Credentials
   CCAI_CLIENT_ID=your-client-id-here
   CCAI_API_KEY=your-api-key-here
   
   # Optional: Suppress LWP Content-Length warnings (set to 1 to enable)
   CCAI_SUPPRESS_WARNINGS=1
   ```

3. **Use in your code:**
   ```perl
   use CCAI;
   use CCAI::EnvLoader;
   
   # Load environment variables from .env file
   CCAI::EnvLoader->load();
   
   # Get credentials from environment
   my ($client_id, $api_key) = CCAI::EnvLoader->get_ccai_credentials();
   
   # Initialize the client
   my $ccai = CCAI->new({
       client_id => $client_id,
       api_key   => $api_key
   });
   ```

### Direct Configuration

You can also configure credentials directly in your code:

```perl
use CCAI;

my $ccai = CCAI->new({
    client_id => 'YOUR-CLIENT-ID',
    api_key   => 'API-KEY-TOKEN'
});
```

## Usage

### SMS with CustomData

```perl
use lib '.';
use CCAI;

# Initialize the client
my $ccai = CCAI->new({
    client_id => 'YOUR-CLIENT-ID',
    api_key   => 'API-KEY-TOKEN'
});

# Send SMS with customData for webhook correlation
my @accounts = (
    {
        first_name => "John",
        last_name  => "Doe",
        phone      => "+15551234567",
        customData => {
            order_id => "ORD-12345",
            customer_type => "premium",
            purchase_amount => 299.99,
            notification_preference => "sms"
        }
    },
    {
        first_name => "Jane",
        last_name  => "Smith", 
        phone      => "+15559876543",
        customData => {
            appointment_id => "APPT-789",
            service_type => "consultation",
            provider => "Dr. Johnson",
            reminder_type => "24hr"
        }
    }
);

my $response = $ccai->sms->send(
    \@accounts,
    "Hello \${first_name} \${last_name}, this is a test message!",
    "Test Campaign"
);

if ($response->{success}) {
    print "SMS sent successfully! Campaign ID: " . $response->{data}->{campaign_id} . "\n";
    print "CustomData will be included in webhook events for tracking.\n";
} else {
    print "Error: " . $response->{error} . "\n";
}

# Send single SMS with customData
my $single_response = $ccai->sms->send_single(
    "Alice",
    "Johnson",
    "+15559876544",
    "Hi \${first_name}, your order is ready!",
    "Order Ready Notification",
    undef,  # options
    {       # customData
        order_id => "ORD-67890",
        pickup_location => "Store #123",
        ready_time => "2025-08-27T14:30:00Z"
    }
);
```

### Webhooks with CustomData

```perl
use lib '.';
use CCAI;

# Initialize the client
my $ccai = CCAI->new({
    client_id => 'YOUR-CLIENT-ID',
    api_key   => 'API-KEY-TOKEN'
});

# Process a webhook event with customData (in your webhook handler)
sub process_webhook_event {
    my ($json, $signature, $secret) = @_;
    
    # Verify the signature
    if ($ccai->webhook->verify_signature($signature, $json, $secret)) {
        # Parse the event
        my $event = $ccai->webhook->parse_event($json);
        
        if ($event && $event->{type} eq "message.sent") {
            print "Message sent to: $event->{to}\n";
            
            # Access customData for business logic
            if ($event->{customData}) {
                my $custom = $event->{customData};
                
                # Handle order-related messages
                if ($custom->{order_id}) {
                    print "Order notification sent: $custom->{order_id}\n";
                    # Update order status in your system
                    # update_order_notification_status($custom->{order_id}, 'sent');
                }
                
                # Handle appointment reminders
                if ($custom->{appointment_id}) {
                    print "Appointment reminder sent: $custom->{appointment_id}\n";
                    # Mark reminder as delivered
                    # mark_reminder_delivered($custom->{appointment_id});
                }
                
                # Customer segmentation
                if ($custom->{customer_type} eq 'premium') {
                    print "Premium customer notification delivered\n";
                    # Special handling for premium customers
                }
            }
        } elsif ($event && $event->{type} eq "message.failed") {
            print "Message failed to: $event->{to}\n";
            
            # Handle failures with context from customData
            if ($event->{customData} && $event->{customData}->{order_id}) {
                print "Order notification failed: " . $event->{customData}->{order_id} . "\n";
                # Implement fallback notification (email, etc.)
                # fallback_notification($event->{customData}->{order_id});
            }
        }
    } else {
        print "Invalid signature\n";
    }
}
### Basic SMS

```perl
use CCAI;

# Initialize the client
my $ccai = CCAI->new({
    client_id => 'YOUR-CLIENT-ID',
    api_key   => 'API-KEY-TOKEN'
});

# Send an SMS to multiple recipients
my @accounts = (
    {
        first_name => "John",
        last_name  => "Doe",
        phone      => "+15551234567"
    },
    {
        first_name => "Jane",
        last_name  => "Smith", 
        phone      => "+15559876543"
    }
);

my $response = $ccai->sms->send(
    \@accounts,
    "Hello \${first_name} \${last_name}, this is a test message!",
    "Test Campaign"
);

if ($response->{success}) {
    print "SMS sent successfully! Campaign ID: " . $response->{data}->{campaign_id} . "\n";
} else {
    print "Error: " . $response->{error} . "\n";
}

# Send an SMS to a single recipient
my $single_response = $ccai->sms->send_single(
    "Jane",
    "Smith",
    "+15559876543",
    "Hi \${first_name}, thanks for your interest!",
    "Single Message Test"
);

if ($single_response->{success}) {
    print "Single SMS sent successfully!\n";
} else {
    print "Error: " . $single_response->{error} . "\n";
}
```

### MMS

```perl
use lib '.';
use CCAI;

# Initialize the client
my $ccai = CCAI->new({
    client_id => 'YOUR-CLIENT-ID',
    api_key   => 'API-KEY-TOKEN'
});

# Define progress callback
my $progress_callback = sub {
    my $status = shift;
    print "Progress: $status\n";
};

# Create options with progress tracking
my $options = {
    timeout     => 60000,
    on_progress => $progress_callback
};

# Complete MMS workflow (get URL, upload image, send MMS)
sub send_mms_with_image {
    # Path to your image file
    my $image_path = 'path/to/your/image.jpg';
    my $content_type = 'image/jpeg';
    
    # Define recipient
    my @accounts = ({
        first_name => 'John',
        last_name  => 'Doe',
        phone      => '+15551234567'
    });
    
    # Send MMS with image in one step
    my $response = $ccai->mms->send_with_image(
        $image_path,
        $content_type,
        \@accounts,
        "Hello \${first_name}, check out this image!",
        "MMS Campaign Example",
        $options
    );
    
    if ($response->{success}) {
        print "MMS sent! Campaign ID: " . $response->{data}->{campaign_id} . "\n";
    } else {
        print "Error sending MMS: " . $response->{error} . "\n";
    }
}

# Call the function
send_mms_with_image();
```

### Email

```perl
use lib '.';
use CCAI;

# Initialize the client
my $ccai = CCAI->new({
    client_id => 'YOUR-CLIENT-ID',
    api_key   => 'API-KEY-TOKEN'
});

# Send a single email
my $response = $ccai->email->send_single(
    "John",                                    # First name
    "Doe",                                     # Last name
    "john@example.com",                        # Email address
    "Welcome to Our Service",                  # Subject
    "<p>Hello \${first_name},</p><p>Thank you for signing up!</p>",  # HTML message content
    "noreply@yourcompany.com",                 # Sender email
    "support@yourcompany.com",                 # Reply-to email
    "Your Company",                            # Sender name
    "Welcome Email"                            # Campaign title
);

if ($response->{success}) {
    print "Email sent successfully! ID: " . $response->{data}->{id} . "\n";
} else {
    print "Error: " . $response->{error} . "\n";
}

# Send an email campaign to multiple recipients
my $campaign = {
    subject => "Monthly Newsletter",
    title => "July 2025 Newsletter",
    message => "<h1>Monthly Newsletter - July 2025</h1><p>Hello \${first_name},</p>",
    sender_email => "newsletter@yourcompany.com",
    reply_email => "support@yourcompany.com",
    sender_name => "Your Company Newsletter",
    accounts => [
        {
            first_name => "John",
            last_name => "Doe",
            email => "john@example.com"
        },
        {
            first_name => "Jane",
            last_name => "Smith",
            email => "jane@example.com"
        }
    ],
    campaign_type => "EMAIL",
    add_to_list => "noList",
    contact_input => "accounts",
    from_type => "single",
    senders => []
};

my $campaign_response = $ccai->email->send_campaign($campaign);

if ($campaign_response->{success}) {
    print "Email campaign sent successfully! ID: " . $campaign_response->{data}->{id} . "\n";
} else {
    print "Error: " . $campaign_response->{error} . "\n";
}
```

### Webhooks

```perl
use lib '.';
use CCAI;

# Initialize the client
my $ccai = CCAI->new({
    client_id => 'YOUR-CLIENT-ID',
    api_key   => 'API-KEY-TOKEN'
});

# Register a webhook
my $webhook_response = $ccai->webhook->register({
    url => "https://example.com/webhook",
    events => ["message.sent", "message.received"],
    secret => "your-webhook-secret"
});

if ($webhook_response->{success}) {
    print "Webhook registered! ID: " . $webhook_response->{data}->{id} . "\n";
    
    # List all webhooks
    my $list_response = $ccai->webhook->list();
    
    if ($list_response->{success}) {
        foreach my $webhook (@{$list_response->{data}}) {
            print "Webhook ID: $webhook->{id}, URL: $webhook->{url}\n";
        }
    }
    
    # Update a webhook
    my $update_response = $ccai->webhook->update(
        $webhook_response->{data}->{id},
        {
            url => "https://example.com/webhook-updated",
            events => ["message.sent"]
        }
    );
    
    # Delete a webhook
    my $delete_response = $ccai->webhook->delete($webhook_response->{data}->{id});
}

# Process a webhook event (in your webhook handler)
sub process_webhook_event {
    my ($json, $signature, $secret) = @_;
    
    # Verify the signature
    if ($ccai->webhook->verify_signature($signature, $json, $secret)) {
        # Parse the event
        my $event = $ccai->webhook->parse_event($json);
        
        if ($event && $event->{type} eq "message.sent") {
            print "Message sent to: $event->{to}\n";
        } elsif ($event && $event->{type} eq "message.received") {
            print "Message received from: $event->{from}\n";
        }
    } else {
        print "Invalid signature\n";
    }
}
```

## Project Structure

- `lib/` - Library modules
  - `CCAI.pm` - Main CCAI client class
  - `CCAI/SMS.pm` - SMS service class
  - `CCAI/MMS.pm` - MMS service class
  - `CCAI/Email.pm` - Email service class
  - `CCAI/Webhook.pm` - Webhook service class
- `examples/` - Example usage scripts
- `t/` - Test files
- `cpanfile` - Dependency specification

## Development

### Prerequisites

- Perl 5.16.0 or higher
- cpanm or cpan for installing dependencies

### Setup

1. Clone the repository
2. Install dependencies: `cpanm --installdeps .`
3. Run examples: `perl examples/sms_example.pl`

### Testing

Run tests with prove:

```bash
# Run all tests
prove -l t/

# Run tests with verbose output
prove -lv t/

# Run specific test file
prove -lv t/01-basic.t
```

## Features

- Object-oriented Perl interface
- Support for sending SMS to multiple recipients
- Support for sending MMS with images
- Support for sending email campaigns
- Support for managing webhooks
- Upload images to S3 with signed URLs
- Support for template variables (first_name, last_name)
- Progress tracking via callbacks
- Comprehensive error handling
- Unit tests
- Modern Perl practices
- **Automatic SSL certificate configuration**

## SSL Certificate Handling

The CCAI client automatically configures SSL certificates using the Mozilla::CA module. If you encounter SSL certificate errors:

1. **Automatic (Recommended)**: The client handles this automatically when Mozilla::CA is installed
2. **Manual**: Set the environment variable:
   ```bash
   export PERL_LWP_SSL_CA_FILE=$(perl -MMozilla::CA -e 'print Mozilla::CA::SSL_ca_file()')
   ```
3. **System CA**: On some systems, you might need:
   ```bash
   export PERL_LWP_SSL_CA_FILE=/etc/ssl/certs/ca-certificates.crt
   ```

## Warning Suppression

The CCAI client may show harmless "Content-Length header value was wrong, fixed" warnings from LWP::UserAgent. These warnings don't affect functionality but can be suppressed:

### Method 1: Environment Variable (Recommended)
```bash
# In your .env file
CCAI_SUPPRESS_WARNINGS=1
```

### Method 2: Programmatically
```perl
my $ccai = CCAI->new({
    client_id => $client_id,
    api_key   => $api_key
});

# Suppress warnings after creating the client
$ccai->suppress_lwp_warnings();
```

### Method 3: In Your Script
```perl
# At the beginning of your script
BEGIN {
    $SIG{__WARN__} = sub {
        my $warning = shift;
        return if $warning =~ /Content-Length header value was wrong, fixed/;
        warn $warning;
    };
}
```

## Error Handling

All methods return a hash reference with the following structure:

```perl
# Success response
{
    success => 1,
    data    => { ... }  # API response data
}

# Error response
{
    success => 0,
    error   => "Error message"
}
```

## Template Variables

Messages support template variables that are automatically replaced:

- `${first_name}` - Replaced with recipient's first name
- `${last_name}` - Replaced with recipient's last name

Example:
```perl
my $message = "Hello \${first_name} \${last_name}, welcome!";
# For John Doe, becomes: "Hello John Doe, welcome!"
```

## License

MIT © 2025 CloudContactAI LLC
