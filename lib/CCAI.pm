package CCAI;

use strict;
use warnings;
use 5.016;

use LWP::UserAgent;
use JSON;
use HTTP::Request::Common qw(GET POST PUT DELETE);
use Carp qw(croak);

# SSL Configuration - Bulletproof approach
BEGIN {
    # Method 1: Set environment variable early
    unless ($ENV{PERL_LWP_SSL_CA_FILE}) {
        eval {
            require Mozilla::CA;
            $ENV{PERL_LWP_SSL_CA_FILE} = Mozilla::CA::SSL_ca_file();
        };
    }
    
    # Method 2: Configure IO::Socket::SSL defaults
    eval {
        require IO::Socket::SSL;
        require Mozilla::CA;
        IO::Socket::SSL::set_defaults(
            SSL_ca_file => Mozilla::CA::SSL_ca_file(),
            SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_PEER(),
        );
    };
}

use CCAI::SMS;
use CCAI::MMS;
use CCAI::Email;
use CCAI::Webhook;

our $VERSION = '1.0.0';

=head1 NAME

CCAI - Perl client for the Cloud Contact AI API

=head1 SYNOPSIS

    use CCAI;
    
    my $ccai = CCAI->new({
        client_id => 'YOUR-CLIENT-ID',
        api_key   => 'API-KEY-TOKEN'
    });
    
    # Send SMS
    my $response = $ccai->sms->send(
        [{
            first_name => "John",
            last_name  => "Doe", 
            phone      => "+15551234567"
        }],
        "Hello \${first_name}!",
        "Test Campaign"
    );
    
    # Send Email
    my $email_response = $ccai->email->send_single(
        "John",
        "Doe",
        "john@example.com",
        "Welcome to Our Service",
        "<p>Hello \${first_name},</p><p>Thank you for signing up!</p>",
        "noreply@yourcompany.com",
        "support@yourcompany.com",
        "Your Company",
        "Welcome Email"
    );
    
    # Register a webhook
    my $webhook_response = $ccai->webhook->register({
        url => "https://example.com/webhook",
        events => ["message.sent", "message.received"],
        secret => "your-webhook-secret"
    });

=head1 DESCRIPTION

CCAI is a Perl client library for the Cloud Contact AI API that allows you to 
easily send SMS and MMS messages, send email campaigns, and manage webhooks.

=head1 METHODS

=head2 new(\%config)

Creates a new CCAI client instance.

    my $ccai = CCAI->new({
        client_id => 'YOUR-CLIENT-ID',
        api_key   => 'API-KEY-TOKEN',
        base_url  => 'https://core.cloudcontactai.com/api'  # optional
    });

Required parameters:
- client_id: Your CCAI client ID
- api_key: Your CCAI API key

Optional parameters:
- base_url: Base URL for the API (defaults to https://core.cloudcontactai.com/api)

=cut

sub new {
    my ($class, $config) = @_;
    
    croak "Configuration hash required" unless $config && ref $config eq 'HASH';
    croak "client_id is required" unless $config->{client_id};
    croak "api_key is required" unless $config->{api_key};
    
    # Configure SSL CA file - Multiple approaches for maximum compatibility
    my $ca_file;
    eval {
        require Mozilla::CA;
        $ca_file = Mozilla::CA::SSL_ca_file();
        
        # Set environment variable (primary method)
        $ENV{PERL_LWP_SSL_CA_FILE} = $ca_file unless $ENV{PERL_LWP_SSL_CA_FILE};
        
        # Also try to configure IO::Socket::SSL directly
        if (eval { require IO::Socket::SSL; 1 }) {
            IO::Socket::SSL::set_defaults(
                SSL_ca_file => $ca_file,
                SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_PEER(),
            );
        }
    };
    
    # Create UserAgent
    my $ua = LWP::UserAgent->new(
        agent   => "CCAI-Perl/$VERSION",
        timeout => 30
    );
    
    # Try multiple SSL configuration methods
    if ($ca_file && -f $ca_file) {
        # Method 1: ssl_opts (if available)
        eval {
            $ua->ssl_opts(
                SSL_ca_file => $ca_file,
                verify_hostname => 1,
                SSL_verify_mode => 1
            );
        };
        
        # Method 2: Direct environment variable setting
        $ENV{HTTPS_CA_FILE} = $ca_file unless $ENV{HTTPS_CA_FILE};
        
        # Method 3: LWP::UserAgent specific SSL configuration
        eval {
            require LWP::Protocol::https;
            # Force reload of https protocol with new settings
        };
    }
    
    my $self = {
        client_id => $config->{client_id},
        api_key   => $config->{api_key},
        base_url  => $config->{base_url} || 'https://core.cloudcontactai.com/api',
        email_url => $config->{email_url} || 'https://email-campaigns.cloudcontactai.com',
        auth_url  => $config->{auth_url} || 'https://auth.cloudcontactai.com',
        ua        => $ua,
        json      => JSON->new->utf8
    };
    
    bless $self, $class;
    
    # Initialize services
    $self->{sms} = CCAI::SMS->new($self);
    $self->{mms} = CCAI::MMS->new($self);
    $self->{email} = CCAI::Email->new($self);
    $self->{webhook} = CCAI::Webhook->new($self);
    
    return $self;
}

=head2 sms

Returns the SMS service instance.

    my $sms_response = $ccai->sms->send(...);

=cut

sub sms {
    my $self = shift;
    return $self->{sms};
}

=head2 mms

Returns the MMS service instance.

    my $mms_response = $ccai->mms->send_with_image(...);

=cut

sub mms {
    my $self = shift;
    return $self->{mms};
}

=head2 email

Returns the Email service instance.

    my $email_response = $ccai->email->send_campaign(...);

=cut

sub email {
    my $self = shift;
    return $self->{email};
}

=head2 webhook

Returns the Webhook service instance.

    my $webhook_response = $ccai->webhook->register(...);

=cut

sub webhook {
    my $self = shift;
    return $self->{webhook};
}

=head2 get_client_id

Returns the client ID.

=cut

sub get_client_id {
    my $self = shift;
    return $self->{client_id};
}

=head2 get_api_key

Returns the API key.

=cut

sub get_api_key {
    my $self = shift;
    return $self->{api_key};
}

=head2 get_base_url

Returns the base URL.

=cut

sub get_base_url {
    my $self = shift;
    return $self->{base_url};
}

=head2 get_email_url

Returns the email URL.

=cut

sub get_email_url {
    my $self = shift;
    return $self->{email_url};
}

=head2 get_auth_url

Returns the auth URL.

=cut

sub get_auth_url {
    my $self = shift;
    return $self->{auth_url};
}

=head2 request($method, $endpoint, $data)

Makes an authenticated API request to the CCAI API.

    my $response = $ccai->request('POST', '/endpoint', { data => 'value' });

Returns a hash reference:
- success: 1 for success, 0 for failure
- data: Response data (on success)
- error: Error message (on failure)

=cut

sub request {
    my ($self, $method, $endpoint, $data) = @_;
    
    my $url = $self->{base_url} . $endpoint;
    my $request;
    
    # Create request based on method
    if (uc($method) eq 'GET') {
        $request = GET($url);
    } elsif (uc($method) eq 'POST') {
        $request = POST($url);
        if ($data) {
            $request->content($self->{json}->encode($data));
        }
    } elsif (uc($method) eq 'PUT') {
        $request = PUT($url);
        if ($data) {
            $request->content($self->{json}->encode($data));
        }
    } elsif (uc($method) eq 'DELETE') {
        $request = DELETE($url);
    } else {
        return {
            success => 0,
            error   => "Unsupported HTTP method: $method"
        };
    }
    
    # Set headers
    $request->header('Authorization' => "Bearer " . $self->{api_key});
    $request->header('Content-Type'  => 'application/json');
    $request->header('Accept'        => '*/*');
    
    # Make the request
    my $response = $self->{ua}->request($request);
    
    if ($response->is_success) {
        my $response_data;
        eval {
            $response_data = $self->{json}->decode($response->content);
        };
        if ($@) {
            return {
                success => 0,
                error   => "Failed to parse JSON response: $@"
            };
        }
        
        return {
            success => 1,
            data    => $response_data
        };
    } else {
        my $error_msg = "API Error: " . $response->status_line;
        if ($response->content) {
            $error_msg .= " - " . $response->content;
        }
        
        return {
            success => 0,
            error   => $error_msg
        };
    }
}

1;

__END__

=head1 AUTHOR

CloudContactAI LLC

=head1 LICENSE

MIT License

Copyright (c) 2025 CloudContactAI LLC

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

=cut
