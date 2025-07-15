package CCAI;

use strict;
use warnings;
use 5.016;

use LWP::UserAgent;
use JSON;
use HTTP::Request::Common qw(GET POST PUT DELETE);
use Carp qw(croak);

use CCAI::SMS;
use CCAI::MMS;

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

=head1 DESCRIPTION

CCAI is a Perl client library for the Cloud Contact AI API that allows you to 
easily send SMS and MMS messages.

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
    
    my $self = {
        client_id => $config->{client_id},
        api_key   => $config->{api_key},
        base_url  => $config->{base_url} || 'https://core.cloudcontactai.com/api',
        ua        => LWP::UserAgent->new(
            agent   => "CCAI-Perl/$VERSION",
            timeout => 30
        ),
        json      => JSON->new->utf8
    };
    
    bless $self, $class;
    
    # Initialize SMS and MMS services
    $self->{sms} = CCAI::SMS->new($self);
    $self->{mms} = CCAI::MMS->new($self);
    
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
