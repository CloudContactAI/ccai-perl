package CCAI::Webhook;

use strict;
use warnings;
use 5.016;

use Carp qw(croak);
use Digest::SHA qw(hmac_sha256_hex);

=head1 NAME

CCAI::Webhook - Webhook management for the CCAI API

=head1 SYNOPSIS

    my $webhook = CCAI::Webhook->new($ccai_instance);
    
    # Register a new webhook
    my $response = $webhook->register({
        url => "https://example.com/webhook",
        events => ["message.sent", "message.received"],
        secret => "your-webhook-secret"
    });
    
    # List all webhooks
    my $webhooks = $webhook->list();
    
    # Verify a webhook signature
    my $is_valid = $webhook->verify_signature($signature, $body, $secret);

=head1 DESCRIPTION

CCAI::Webhook handles webhook management for the Cloud Contact AI platform.

=head1 METHODS

=head2 new($ccai)

Creates a new Webhook service instance.

    my $webhook = CCAI::Webhook->new($ccai_instance);

=cut

sub new {
    my ($class, $ccai) = @_;
    
    croak "CCAI instance required" unless $ccai;
    
    my $self = {
        ccai => $ccai
    };
    
    bless $self, $class;
    return $self;
}

=head2 register(\%config)

Register a new webhook endpoint.

    my $response = $webhook->register({
        url => "https://example.com/webhook",
        events => ["message.sent", "message.received"],
        secret => "your-webhook-secret"
    });

Parameters:
- config: Hash reference with webhook configuration
  - url: URL to receive webhook events
  - events: Array reference of event types to subscribe to
  - secret: Optional secret for webhook signature verification

Returns a hash reference:
- success: 1 for success, 0 for failure
- data: Response data (on success)
- error: Error message (on failure)

=cut

sub register {
    my ($self, $config) = @_;
    
    # Validate inputs
    unless ($config && ref $config eq 'HASH') {
        return {
            success => 0,
            error => 'Webhook configuration is required'
        };
    }
    
    unless ($config->{url}) {
        return {
            success => 0,
            error => 'URL is required'
        };
    }
    
    unless ($config->{events} && ref $config->{events} eq 'ARRAY' && @{$config->{events}} > 0) {
        return {
            success => 0,
            error => 'At least one event type is required'
        };
    }
    
    # Prepare the API request data
    my $request_data = {
        url => $config->{url},
        events => $config->{events}
    };
    
    # Add secret if provided
    $request_data->{secret} = $config->{secret} if defined $config->{secret};
    
    # Make the API request
    return $self->{ccai}->request('POST', '/webhooks', $request_data);
}

=head2 update($id, \%config)

Update an existing webhook configuration.

    my $response = $webhook->update("webhook-123", {
        url => "https://example.com/webhook-updated",
        events => ["message.sent"],
        secret => "your-updated-secret"
    });

Parameters:
- id: Webhook ID
- config: Hash reference with updated webhook configuration
  - url: URL to receive webhook events
  - events: Array reference of event types to subscribe to
  - secret: Optional secret for webhook signature verification

Returns a hash reference:
- success: 1 for success, 0 for failure
- data: Response data (on success)
- error: Error message (on failure)

=cut

sub update {
    my ($self, $id, $config) = @_;
    
    # Validate inputs
    unless ($id) {
        return {
            success => 0,
            error => 'Webhook ID is required'
        };
    }
    
    unless ($config && ref $config eq 'HASH') {
        return {
            success => 0,
            error => 'Webhook configuration is required'
        };
    }
    
    # Prepare the API request data
    my $request_data = {};
    
    # Add fields if provided
    $request_data->{url} = $config->{url} if defined $config->{url};
    $request_data->{events} = $config->{events} if defined $config->{events};
    $request_data->{secret} = $config->{secret} if defined $config->{secret};
    
    # Make the API request
    return $self->{ccai}->request('PUT', "/webhooks/$id", $request_data);
}

=head2 list()

List all registered webhooks.

    my $response = $webhook->list();

Returns a hash reference:
- success: 1 for success, 0 for failure
- data: Array of webhook configurations (on success)
- error: Error message (on failure)

=cut

sub list {
    my ($self) = @_;
    
    # Make the API request
    return $self->{ccai}->request('GET', '/webhooks');
}

=head2 delete($id)

Delete a webhook.

    my $response = $webhook->delete("webhook-123");

Parameters:
- id: Webhook ID

Returns a hash reference:
- success: 1 for success, 0 for failure
- data: Success message (on success)
- error: Error message (on failure)

=cut

sub delete {
    my ($self, $id) = @_;
    
    # Validate inputs
    unless ($id) {
        return {
            success => 0,
            error => 'Webhook ID is required'
        };
    }
    
    # Make the API request
    return $self->{ccai}->request('DELETE', "/webhooks/$id");
}

=head2 verify_signature($signature, $body, $secret)

Verify a webhook signature.

    my $is_valid = $webhook->verify_signature(
        $signature,  # From X-CCAI-Signature header
        $body,       # Raw request body
        $secret      # Webhook secret
    );

Parameters:
- signature: Signature from the X-CCAI-Signature header
- body: Raw request body
- secret: Webhook secret

Returns:
- 1 if the signature is valid
- 0 if the signature is invalid

=cut

sub verify_signature {
    my ($self, $signature, $body, $secret) = @_;
    
    # Validate inputs
    return 0 unless $signature && $body && $secret;
    
    # Compute HMAC-SHA256 signature
    my $computed_signature = hmac_sha256_hex($body, $secret);
    
    # Compare signatures
    return $signature eq $computed_signature ? 1 : 0;
}

=head2 parse_event($json)

Parse a webhook event from JSON.

    my $event = $webhook->parse_event($json);
    
    if ($event->{type} eq 'message.sent') {
        print "Message sent to: $event->{to}\n";
    } elsif ($event->{type} eq 'message.received') {
        print "Message received from: $event->{from}\n";
    }

Parameters:
- json: JSON string from webhook request body

Returns:
- Hash reference with parsed event data
- undef if parsing fails

=cut

sub parse_event {
    my ($self, $json) = @_;
    
    # Validate input
    unless ($json) {
        return undef;
    }
    
    # Parse JSON
    my $event;
    eval {
        $event = $self->{ccai}->{json}->decode($json);
    };
    if ($@) {
        return undef;
    }
    
    # Validate event type
    unless ($event->{type}) {
        return undef;
    }
    
    return $event;
}

1;

__END__

=head1 AUTHOR

CloudContactAI LLC

=head1 LICENSE

MIT License

Copyright (c) 2025 CloudContactAI LLC

=cut
