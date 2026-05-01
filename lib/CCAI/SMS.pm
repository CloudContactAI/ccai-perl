package CCAI::SMS;

use strict;
use warnings;
use 5.016;

use Carp qw(croak);

=head1 NAME

CCAI::SMS - SMS service for the CCAI API

=head1 SYNOPSIS

    my $sms = CCAI::SMS->new($ccai_instance);
    
    my $response = $sms->send(
        [{
            firstName => "John",
            lastName  => "Doe",
            phone      => "+15551234567"
        }],
        "Hello \${firstName} \${lastName}!",
        "Test Campaign"
    );

=head1 DESCRIPTION

CCAI::SMS handles sending SMS messages through the Cloud Contact AI platform.

=head1 METHODS

=head2 new($ccai)

Creates a new SMS service instance.

    my $sms = CCAI::SMS->new($ccai_instance);

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

=head2 send(\@accounts, $message, $title, \%options)

Send an SMS message to one or more recipients.

    my $response = $sms->send(
        [{
            firstName => "John",
            lastName  => "Doe", 
            phone      => "+15551234567"
        }],
        "Hello \${firstName} \${lastName}!",
        "Test Campaign",
        {
            timeout     => 60000,
            on_progress => sub { print "Status: $_[0]\n" }
        }
    );

Parameters:
- accounts: Array reference of recipient hash references
- message: The message to send (can include ${firstName} and ${lastName} variables)
- title: Campaign title
- options: Optional hash reference with settings

Each account hash should contain:
- firstName: Recipient's first name
- lastName: Recipient's last name
- phone: Recipient's phone number (E.164 format)
- data: Optional hash reference for variable substitution in message templates (wire: "data")
- messageData: Optional string forwarded as-is to your webhook handler (wire: "messageData")

Options hash can contain:
- timeout: Optional timeout in milliseconds
- retries: Optional retry count for failed requests
- on_progress: Optional callback for tracking progress

Returns a hash reference:
- success: 1 for success, 0 for failure
- data: Response data (on success)
- error: Error message (on failure)

=cut

sub send {
    my ($self, $accounts, $message, $title, $sender_phone, $options) = @_;
    
    # Validate inputs
    unless ($accounts && ref $accounts eq 'ARRAY' && @$accounts > 0) {
        return {
            success => 0,
            error   => 'At least one account is required'
        };
    }
    
    unless ($message) {
        return {
            success => 0,
            error   => 'Message is required'
        };
    }
    
    unless ($title) {
        return {
            success => 0,
            error   => 'Campaign title is required'
        };
    }
    
    # Validate each account has the required fields
    for my $i (0 .. $#$accounts) {
        my $account = $accounts->[$i];
        
        unless ($account->{firstName}) {
            return {
                success => 0,
                error   => "First name is required for account at index $i"
            };
        }
        
        unless ($account->{lastName}) {
            return {
                success => 0,
                error   => "Last name is required for account at index $i"
            };
        }
        
        unless ($account->{phone}) {
            return {
                success => 0,
                error   => "Phone number is required for account at index $i"
            };
        }
    }
    
    # Notify progress if callback provided
    if ($options && $options->{on_progress}) {
        $options->{on_progress}->('Preparing to send SMS');
    }
    
    my $endpoint = "/clients/" . $self->{ccai}->get_client_id() . "/campaigns/direct";

    # Map customData → messageData (API wire format)
    my @mapped_accounts = map {
        my %acc = %$_;
        if (exists $acc{customData}) {
            $acc{messageData} = delete $acc{customData};
        }
        \%acc;
    } @$accounts;

    my $campaign_data = {
        accounts => \@mapped_accounts,
        message  => $message,
        title    => $title
    };
    $campaign_data->{senderPhone} = $sender_phone if $sender_phone;
    
    # Notify progress if callback provided
    if ($options && $options->{on_progress}) {
        $options->{on_progress}->('Sending SMS');
    }
    
    # Make the API request
    my $response = $self->{ccai}->request('POST', $endpoint, $campaign_data);
    
    # Notify progress if callback provided
    if ($options && $options->{on_progress}) {
        if ($response->{success}) {
            $options->{on_progress}->('SMS sent successfully');
        } else {
            $options->{on_progress}->('SMS sending failed');
        }
    }
    
    return $response;
}

=head2 send_single($firstName, $lastName, $phone, $message, $title, \%options, \%data, $message_data)

Send a single SMS message to one recipient.

    my $response = $sms->send_single(
        "Jane",
        "Smith",
        "+15559876543",
        "Hi \${firstName}, from \${city}!",
        "Single Message Test",
        undef,                                        # options
        { city => "Miami", plan => "premium" },       # data (template variables → wire: "data")
        '{"orderId":"123","source":"checkout"}'       # message_data (webhook payload → wire: "messageData")
    );

Parameters:
- firstName: Recipient's first name
- lastName: Recipient's last name
- phone: Recipient's phone number (E.164 format)
- message: The message to send (can include ${firstName}, ${lastName}, and any key from data)
- title: Campaign title
- options: Optional hash reference with settings
- data: Optional hash reference for variable substitution in message templates (sent as "data")
- message_data: Optional string forwarded as-is to your webhook handler (sent as "messageData")

Returns a hash reference:
- success: 1 for success, 0 for failure
- data: Response data (on success)
- error: Error message (on failure)

=cut

sub send_single {
    my ($self, $firstName, $lastName, $phone, $message, $title, $options, $data, $message_data, $sender_phone) = @_;

    my $account = {
        firstName => $firstName,
        lastName  => $lastName,
        phone     => $phone
    };

    # Add data (template variable substitution) if provided
    if ($data && ref $data eq 'HASH') {
        $account->{data} = $data;
    }

    # Add messageData (webhook payload string) if provided
    if (defined $message_data && $message_data ne '') {
        $account->{messageData} = $message_data;
    }

    return $self->send([$account], $message, $title, $sender_phone, $options);
}

1;

__END__

=head1 AUTHOR

CloudContactAI LLC

=head1 LICENSE

MIT License

Copyright (c) 2026 CloudContactAI LLC

=cut
