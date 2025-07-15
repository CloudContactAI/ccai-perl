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
            first_name => "John",
            last_name  => "Doe",
            phone      => "+15551234567"
        }],
        "Hello \${first_name} \${last_name}!",
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
            first_name => "John",
            last_name  => "Doe", 
            phone      => "+15551234567"
        }],
        "Hello \${first_name} \${last_name}!",
        "Test Campaign",
        {
            timeout     => 60000,
            on_progress => sub { print "Status: $_[0]\n" }
        }
    );

Parameters:
- accounts: Array reference of recipient hash references
- message: The message to send (can include ${first_name} and ${last_name} variables)
- title: Campaign title
- options: Optional hash reference with settings

Each account hash should contain:
- first_name: Recipient's first name
- last_name: Recipient's last name  
- phone: Recipient's phone number (E.164 format)

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
    my ($self, $accounts, $message, $title, $options) = @_;
    
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
        
        unless ($account->{first_name}) {
            return {
                success => 0,
                error   => "First name is required for account at index $i"
            };
        }
        
        unless ($account->{last_name}) {
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
    
    my $campaign_data = {
        accounts => $accounts,
        message  => $message,
        title    => $title
    };
    
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

=head2 send_single($first_name, $last_name, $phone, $message, $title, \%options)

Send a single SMS message to one recipient.

    my $response = $sms->send_single(
        "Jane",
        "Smith", 
        "+15559876543",
        "Hi \${first_name}, thanks for your interest!",
        "Single Message Test"
    );

Parameters:
- first_name: Recipient's first name
- last_name: Recipient's last name
- phone: Recipient's phone number (E.164 format)
- message: The message to send (can include ${first_name} and ${last_name} variables)
- title: Campaign title
- options: Optional hash reference with settings

Returns a hash reference:
- success: 1 for success, 0 for failure
- data: Response data (on success)
- error: Error message (on failure)

=cut

sub send_single {
    my ($self, $first_name, $last_name, $phone, $message, $title, $options) = @_;
    
    my $account = {
        first_name => $first_name,
        last_name  => $last_name,
        phone      => $phone
    };
    
    return $self->send([$account], $message, $title, $options);
}

1;

__END__

=head1 AUTHOR

CloudContactAI LLC

=head1 LICENSE

MIT License

Copyright (c) 2025 CloudContactAI LLC

=cut
