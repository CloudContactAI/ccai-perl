# Changelog

All notable changes to the CCAI Perl client will be documented in this file.

## [1.3.0] - 2025-08-27

### Added
- **CustomData Support**: Added ability to pass custom data with SMS messages that will be included in webhook events
- **Environment Variable Support**: Added `.env` file support for configuration management
- New `CCAI::EnvLoader` module for loading environment variables from `.env` files
- New `customData` field support in account objects for SMS sending
- Enhanced `send_single()` method to accept optional customData parameter
- Updated webhook event parsing to handle customData in webhook events
- Comprehensive examples demonstrating customData usage:
  - `examples/sms_custom_data_example.pl` - SMS sending with customData
  - `examples/webhook_custom_data_example.pl` - Webhook handling with customData
  - `examples/complete_custom_data_workflow.pl` - End-to-end workflow example
- New test suite `t/03-custom-data.t` for customData functionality
- New test suite `t/04-env-loader.t` for environment variable loading
- Enhanced documentation in README.md with customData usage examples
- Added `.env.example` file for easy configuration setup

### Enhanced
- Updated all examples to use environment variables from `.env` files
- Updated SMS module documentation to include customData field descriptions
- Updated Webhook module documentation to describe customData in webhook events
- Improved business process integration capabilities through customData correlation
- Enhanced webhook event handling with custom data correlation
- Better error messages for missing credentials with helpful setup instructions

### Configuration
- Added support for `.env` file configuration:
  ```bash
  cp .env.example .env
  # Edit .env with your credentials
  ```
- Environment variables supported:
  - `CCAI_CLIENT_ID` - Your CCAI Client ID
  - `CCAI_API_KEY` - Your CCAI API Key

### Technical Details
- CustomData is passed as a hash reference in account objects
- CustomData is preserved exactly as sent in webhook notifications
- Backward compatibility maintained - customData is optional
- All existing functionality remains unchanged

### Use Cases
- E-commerce order tracking and notifications
- Healthcare appointment reminders with patient context
- Service request management and technician routing
- Customer segmentation and personalized handling
- Analytics and business intelligence correlation
- Audit trails and compliance tracking

### Examples of CustomData Usage

#### SMS with CustomData
```perl
my @accounts = (
    {
        first_name => "John",
        last_name  => "Doe",
        phone      => "+15551234567",
        customData => {
            order_id => "ORD-12345",
            customer_type => "premium",
            purchase_amount => 299.99
        }
    }
);
```

#### Webhook Event with CustomData
```perl
my $event = $ccai->webhook->parse_event($json);
if ($event->{customData}) {
    my $order_id = $event->{customData}->{order_id};
    # Handle business logic based on order_id
}
```

## [1.2.0] - Previous Release
- Email campaign support
- MMS functionality
- Webhook management
- SSL certificate handling

## [1.1.0] - Previous Release
- Basic SMS functionality
- Multi-recipient support
- Template variables

## [1.0.0] - Initial Release
- Core CCAI API client
- Basic SMS sending
- Error handling
