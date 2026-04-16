package CCAI::Webhook;

use strict;
use warnings;
use 5.016;

use Carp qw(croak);
use Digest::SHA qw(hmac_sha256);
use MIME::Base64 qw(encode_base64);

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
        return { success => 0, error => 'Webhook configuration is required' };
    }

    unless ($config->{url}) {
        return { success => 0, error => 'URL is required' };
    }

    my $client_id = $self->{ccai}->get_client_id();
    my $payload = [{
        url             => $config->{url},
        method          => 'POST',
        integrationType => $config->{integration_type} // 'ALL',
    }];

    # Only include secretKey if explicitly provided
    if (defined $config->{secret}) {
        $payload->[0]->{secretKey} = $config->{secret};
    }

    my $result = $self->{ccai}->request('POST', "/v1/client/$client_id/integration", $payload);
    return $result unless $result->{success};

    # Unwrap first element from array response
    my $data = ref $result->{data} eq 'ARRAY' ? $result->{data}[0] : $result->{data};
    return { success => 1, data => $data };
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

    unless ($id) {
        return { success => 0, error => 'Webhook ID is required' };
    }

    unless ($config && ref $config eq 'HASH') {
        return { success => 0, error => 'Webhook configuration is required' };
    }

    my $client_id = $self->{ccai}->get_client_id();
    my $payload = [{
        id              => $id + 0,
        url             => $config->{url},
        method          => 'POST',
        integrationType => $config->{integration_type} // 'ALL',
    }];

    # Only include secretKey if explicitly provided
    if (defined $config->{secret}) {
        $payload->[0]->{secretKey} = $config->{secret};
    }

    my $result = $self->{ccai}->request('POST', "/v1/client/$client_id/integration", $payload);
    return $result unless $result->{success};

    my $data = ref $result->{data} eq 'ARRAY' ? $result->{data}[0] : $result->{data};
    return { success => 1, data => $data };
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

    my $client_id = $self->{ccai}->get_client_id();
    return $self->{ccai}->request('GET', "/v1/client/$client_id/integration");
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

    unless ($id) {
        return { success => 0, error => 'Webhook ID is required' };
    }

    my $client_id = $self->{ccai}->get_client_id();
    return $self->{ccai}->request('DELETE', "/v1/client/$client_id/integration/$id");
}

=head2 verify_signature($signature, $client_id, $event_hash, $secret)

Verify a webhook signature using HMAC-SHA256.

Signature is computed as: HMAC-SHA256(secretKey, clientId:eventHash) encoded in Base64

    my $is_valid = $webhook->verify_signature(
        $signature,   # From X-CCAI-Signature header (Base64 encoded)
        $client_id,   # Client ID
        $event_hash,  # Event hash from the webhook payload
        $secret       # Webhook secret
    );

Parameters:
- signature: Signature from the X-CCAI-Signature header (Base64 encoded)
- client_id: Client ID
- event_hash: Event hash from the webhook payload
- secret: Webhook secret

Returns:
- 1 if the signature is valid
- 0 if the signature is invalid

=cut

sub verify_signature {
    my ($self, $signature, $client_id, $event_hash, $secret) = @_;

    # Validate inputs
    return 0 unless $signature && $client_id && $event_hash && $secret;

    # Compute: HMAC-SHA256(secretKey, "$clientId:$eventHash")
    my $data = "$client_id:$event_hash";
    my $computed = hmac_sha256($data, $secret);

    # Encode result in Base64 (remove trailing newline)
    my $computed_base64 = encode_base64($computed, '');

    # Constant-time comparison to prevent timing attacks
    return $self->_constant_time_compare($signature, $computed_base64);
}

=head2 handle_event($json, $callback)

Parse and handle a CloudContact webhook event with a single unified function.

    my $webhook = CCAI::Webhook->new($ccai);
    
    $webhook->handle_event($json_payload, sub {
        my ($event_type, $data) = @_;
        
        if ($event_type eq 'message.sent') {
            print "✅ Message delivered to $data->{To}\n";
            print "   Cost: \$$data->{TotalPrice}\n";
            print "   Segments: $data->{Segments}\n";
        } elsif ($event_type eq 'message.incoming') {
            print "📨 Reply from $data->{From}: $data->{Message}\n";
        } elsif ($event_type eq 'message.excluded') {
            print "⚠️ Message excluded: $data->{ExcludedReason}\n";
        } elsif ($event_type eq 'message.error.carrier') {
            print "❌ Carrier error $data->{ErrorCode}: $data->{ErrorMessage}\n";
        } elsif ($event_type eq 'message.error.cloudcontact') {
            print "🚨 System error $data->{ErrorCode}: $data->{ErrorMessage}\n";
        }
    });

Parameters:
- json: JSON string from webhook request body
- callback: Code reference that receives ($event_type, $data)

Supported Event Types:
- message.sent: Message successfully delivered
- message.incoming: Reply received from recipient
- message.excluded: Message excluded during campaign
- message.error.carrier: Carrier-level delivery failure
- message.error.cloudcontact: CloudContact system error

Returns:
- 1 if event was successfully parsed and handled
- 0 if parsing failed or invalid event

=cut

# Constant-time string comparison to prevent timing attacks
#
# Compares two strings byte-by-byte without short-circuiting,
# regardless of whether they match early in the string.
#
# @param a [Str] First string to compare
# @param b [Str] Second string to compare
# @return [Bool] 1 if strings match, 0 otherwise
sub _constant_time_compare {
    my ($self, $a, $b) = @_;

    # If lengths differ, they don't match, but still compare all bytes
    my $match = (length($a) == length($b)) ? 1 : 0;

    my $len_a = length($a);
    my $len_b = length($b);
    my $max_len = $len_a > $len_b ? $len_a : $len_b;

    # Compare all bytes (pad shorter string with nulls)
    my @a_bytes = split //, $a;
    my @b_bytes = split //, $b;

    for (my $i = 0; $i < $max_len; $i++) {
        my $a_byte = $i < $len_a ? ord($a_bytes[$i]) : 0;
        my $b_byte = $i < $len_b ? ord($b_bytes[$i]) : 0;
        $match &= ($a_byte == $b_byte) ? 1 : 0;
    }

    return $match;
}

sub handle_event {
    my ($self, $json, $callback) = @_;

    # Validate inputs
    unless ($json && $callback && ref $callback eq 'CODE') {
        return 0;
    }
    
    # Parse JSON
    my $event;
    eval {
        $event = $self->{ccai}->{json}->decode($json);
    };
    if ($@) {
        return 0;
    }
    
    # Validate CloudContact event structure
    unless ($event->{eventType} && $event->{data}) {
        return 0;
    }
    
    my $event_type = $event->{eventType};
    my $data = $event->{data};
    
    # Validate supported event types
    my %supported_events = (
        'message.sent' => 1,
        'message.incoming' => 1,
        'message.excluded' => 1,
        'message.error.carrier' => 1,
        'message.error.cloudcontact' => 1
    );
    
    unless ($supported_events{$event_type}) {
        return 0;
    }
    
    # Call the callback with event type and data
    eval {
        $callback->($event_type, $data);
    };
    if ($@) {
        return 0;
    }
    
    return 1;
}

=head2 parse_event($json)

Parse a webhook event from JSON (legacy method for backward compatibility).

    my $event = $webhook->parse_event($json);

Parameters:
- json: JSON string from webhook request body

Returns:
- Hash reference with parsed event data
- undef if parsing fails

Note: This method is deprecated. Use handle_event() for new CloudContact event format.

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
    
    # Handle new CloudContact format
    if ($event->{eventType} && $event->{data}) {
        return {
            type => $event->{eventType},
            %{$event->{data}}
        };
    }
    
    # Handle legacy format
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

Copyright (c) 2026 CloudContactAI LLC

=cut
