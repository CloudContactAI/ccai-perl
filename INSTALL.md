# CCAI Perl Client - Installation Guide

## Quick Start

1. **Install dependencies:**
   ```bash
   # Using cpanm (recommended)
   cpanm --installdeps .
   
   # Or install individual modules
   cpanm LWP::UserAgent JSON HTTP::Request::Common File::Basename MIME::Base64 File::Slurp
   ```

2. **Run tests:**
   ```bash
   perl -Ilib -MTest::Harness -e 'runtests(@ARGV)' t/*.t
   ```

3. **Try examples:**
   ```bash
   # Update credentials in examples first
   perl -Ilib examples/sms_send.pl
   perl -Ilib examples/mms_send.pl
   perl -Ilib examples/email_example.pl
   ```

## Installation Methods

### Method 1: Using cpanm (Recommended)

```bash
# Install cpanm if you don't have it
curl -L https://cpanmin.us | perl - --sudo App::cpanminus

# Install dependencies
cpanm --installdeps .
```

### Method 2: Using cpan

```bash
cpan LWP::UserAgent JSON HTTP::Request::Common File::Basename MIME::Base64 File::Slurp
```

### Method 3: Manual Installation

```bash
# For each required module, run:
perl -MCPAN -e 'install Module::Name'
```

## SSL Certificate Issues

The CCAI client automatically handles SSL certificate configuration. If you encounter SSL certificate errors, the client will automatically:

1. **Auto-configure**: Uses Mozilla::CA certificate bundle automatically
2. **Set SSL options**: Configures LWP::UserAgent with proper SSL settings
3. **Fallback gracefully**: Works even if SSL modules aren't perfectly configured

### Manual SSL Configuration (if needed)

If you still encounter SSL issues:

#### Option 1: Install Mozilla::CA (Recommended)
```bash
cpanm Mozilla::CA
```

#### Option 2: Set CA file environment variable
```bash
export PERL_LWP_SSL_CA_FILE=$(perl -MMozilla::CA -e 'print Mozilla::CA::SSL_ca_file()')
```

#### Option 3: System CA bundle (Linux/macOS)
```bash
# Linux
export PERL_LWP_SSL_CA_FILE=/etc/ssl/certs/ca-certificates.crt

# macOS with Homebrew
export PERL_LWP_SSL_CA_FILE=/usr/local/etc/openssl/cert.pem
```

#### Option 4: Disable SSL verification (NOT recommended for production)
```bash
export PERL_LWP_SSL_VERIFY_HOSTNAME=0
```

**Note**: The CCAI client handles SSL configuration automatically when Mozilla::CA is installed, so manual configuration is rarely needed.

## Testing

Run the test suite to verify everything is working:

```bash
# Run all tests
prove -l t/

# Run with verbose output
prove -lv t/

# Run specific test
prove -lv t/01-basic.t
```

## Development Setup

For development work:

```bash
# Clone/download the project
cd ccai-perl

# Install dependencies
cpanm --installdeps .

# Install development dependencies
cpanm Test::More Test::Exception

# Run tests
prove -l t/

# Check syntax
perl -c lib/CCAI.pm
perl -c lib/CCAI/SMS.pm
perl -c lib/CCAI/MMS.pm
```

## Building Distribution

To create a distributable package:

```bash
# Generate Makefile
perl Makefile.PL

# Build
make

# Test
make test

# Create distribution
make dist
```

## Troubleshooting

### Common Issues

1. **Module not found errors:**
   - Ensure you're using `-Ilib` flag when running scripts
   - Check that all dependencies are installed

2. **SSL/TLS errors:**
   - Install Mozilla::CA module
   - Or set appropriate environment variables

3. **Permission errors:**
   - Use `sudo` with cpanm if needed
   - Or install to local directory with `cpanm -l local/`

### Getting Help

- Check the README.md for usage examples
- Review the test files in `t/` for more examples
- Look at the comprehensive example in `examples/`

## Requirements

- Perl 5.16.0 or higher
- Internet connection for API calls
- Valid CCAI credentials (client_id and api_key)

## Next Steps

1. Get your CCAI credentials from the CloudContactAI dashboard
2. Update the example scripts with your credentials
3. Test with a small SMS campaign
4. Integrate into your Perl applications

For more information, see the main README.md file.
