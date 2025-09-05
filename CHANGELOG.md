# Changelog

All notable changes to the CCAI Perl client will be documented in this file.

## [1.4.0] - 2025-09-05

### Added
- **Unified Webhook Event Handler**: New `handle_event()` method in `CCAI::Webhook` that processes all CloudContact webhook event types with a single callback function
- Support for 5 CloudContact webhook event types:
  - `message.sent` - Message successfully delivered with pricing and segment info
  - `message.incoming` - Reply received from recipient
  - `message.excluded` - Message excluded during campaign with exclusion reason
  - `message.error.carrier` - Carrier-level delivery failure with error codes
  - `message.error.cloudcontact` - CloudContact system error with error details
- New unified webhook server: `unified_webhook_server.pl`
- New comprehensive webhook example: `examples/unified_webhook_example.pl`

### Changed
- **BREAKING**: Updated all parameter names from snake_case to camelCase:
  - `first_name` → `firstName`
  - `last_name` → `lastName`
- Enhanced `CCAI::Webhook` module with unified event processing
- Updated all examples and documentation to use camelCase parameters
- Cleaned up redundant example files and utilities

### Removed
- Redundant webhook server implementations
- Duplicate example files (`mms_example.pl`, `comprehensive_example.pl`, etc.)
- Old webhook examples superseded by unified approach
- Test files moved to proper test suite

### Fixed
- Updated MANIFEST to reflect current file structure
- Corrected documentation references to existing files
- Maintained backward compatibility for existing webhook parsing

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
        firstName => "John",
        lastName  => "Doe",
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
