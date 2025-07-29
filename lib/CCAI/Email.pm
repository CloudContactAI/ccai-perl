package CCAI::Email;

use strict;
use warnings;
use 5.016;

use Carp qw(croak);

=head1 NAME

CCAI::Email - Email service for the CCAI API

=head1 SYNOPSIS

    my $email = CCAI::Email->new($ccai_instance);
    
    my $response = $email->send_campaign(
        {
            subject => "Test Subject",
            title => "Test Campaign",
            message => "<p>Hello \${first_name},</p><p>This is a test email.</p>",
            sender_email => "sender@example.com",
            reply_email => "reply@example.com",
            sender_name => "Test Sender",
            accounts => [
                {
                    first_name => "John",
                    last_name => "Doe",
                    email => "john@example.com"
                }
            ]
        }
    );

=head1 DESCRIPTION

CCAI::Email handles sending email campaigns through the Cloud Contact AI platform.

=head1 METHODS

=head2 new($ccai)

Creates a new Email service instance.

    my $email = CCAI::Email->new($ccai_instance);

=cut

sub new {
    my ($class, $ccai) = @_;
    
    croak "CCAI instance required" unless $ccai;
    
    my $self = {
        ccai => $ccai,
        base_url => $ccai->get_email_url() . '/api/v1'
    };
    
    bless $self, $class;
    return $self;
}

=head2 send_campaign(\%campaign, \%options)

Send an email campaign to one or more recipients.

    my $response = $email->send_campaign(
        {
            subject => "Test Subject",
            title => "Test Campaign",
            message => "<p>Hello \${first_name},</p><p>This is a test email.</p>",
            sender_email => "sender@example.com",
            reply_email => "reply@example.com",
            sender_name => "Test Sender",
            accounts => [
                {
                    first_name => "John",
                    last_name => "Doe",
                    email => "john@example.com"
                }
            ],
            campaign_type => "EMAIL",
            add_to_list => "noList",
            contact_input => "accounts",
            from_type => "single",
            senders => []
        },
        {
            timeout => 60000,
            on_progress => sub { print "Status: $_[0]\n" }
        }
    );

Parameters:
- campaign: Hash reference with campaign configuration
- options: Optional hash reference with settings

Campaign hash should contain:
- subject: Email subject
- title: Campaign title
- message: HTML message content
- sender_email: Sender's email address
- reply_email: Reply-to email address
- sender_name: Sender's name
- accounts: Array reference of recipient hash references
- campaign_type: Must be "EMAIL"
- add_to_list: List handling ("noList" or other options)
- contact_input: How contacts are provided ("accounts")
- from_type: From type ("single" or other options)
- senders: Array reference of additional senders (usually empty)

Optional campaign fields:
- editor: Optional editor information
- file_key: Optional file key
- scheduled_timestamp: Optional ISO timestamp for scheduling
- scheduled_timezone: Optional timezone for scheduling
- selected_list: Optional selected list
- list_id: Optional list ID
- replace_contacts: Optional replace contacts flag
- email_template_id: Optional template ID
- flux_id: Optional flux ID

Each account hash should contain:
- first_name: Recipient's first name
- last_name: Recipient's last name
- email: Recipient's email address

Options hash can contain:
- timeout: Optional timeout in milliseconds
- retries: Optional retry count for failed requests
- on_progress: Optional callback for tracking progress

Returns a hash reference:
- success: 1 for success, 0 for failure
- data: Response data (on success)
- error: Error message (on failure)

=cut

sub send_campaign {
    my ($self, $campaign, $options) = @_;
    
    # Validate inputs
    unless ($campaign && ref $campaign eq 'HASH') {
        return {
            success => 0,
            error => 'Campaign configuration is required'
        };
    }
    
    unless ($campaign->{accounts} && ref $campaign->{accounts} eq 'ARRAY' && @{$campaign->{accounts}} > 0) {
        return {
            success => 0,
            error => 'At least one account is required'
        };
    }
    
    unless ($campaign->{subject}) {
        return {
            success => 0,
            error => 'Subject is required'
        };
    }
    
    unless ($campaign->{title}) {
        return {
            success => 0,
            error => 'Campaign title is required'
        };
    }
    
    unless ($campaign->{message}) {
        return {
            success => 0,
            error => 'Message content is required'
        };
    }
    
    unless ($campaign->{sender_email}) {
        return {
            success => 0,
            error => 'Sender email is required'
        };
    }
    
    unless ($campaign->{reply_email}) {
        return {
            success => 0,
            error => 'Reply email is required'
        };
    }
    
    unless ($campaign->{sender_name}) {
        return {
            success => 0,
            error => 'Sender name is required'
        };
    }
    
    # Validate each account has the required fields
    for my $i (0 .. $#{$campaign->{accounts}}) {
        my $account = $campaign->{accounts}->[$i];
        
        unless ($account->{first_name}) {
            return {
                success => 0,
                error => "First name is required for account at index $i"
            };
        }
        
        unless ($account->{last_name}) {
            return {
                success => 0,
                error => "Last name is required for account at index $i"
            };
        }
        
        unless ($account->{email}) {
            return {
                success => 0,
                error => "Email is required for account at index $i"
            };
        }
    }
    
    # Notify progress if callback provided
    if ($options && $options->{on_progress}) {
        $options->{on_progress}->('Preparing to send email campaign');
    }
    
    # Prepare the API request data
    my $request_data = {
        subject => $campaign->{subject},
        title => $campaign->{title},
        message => $campaign->{message},
        senderEmail => $campaign->{sender_email},
        replyEmail => $campaign->{reply_email},
        senderName => $campaign->{sender_name},
        accounts => $campaign->{accounts},
        campaignType => $campaign->{campaign_type} || 'EMAIL',
        addToList => $campaign->{add_to_list} || 'noList',
        contactInput => $campaign->{contact_input} || 'accounts',
        fromType => $campaign->{from_type} || 'single',
        senders => $campaign->{senders} || []
    };
    
    # Add optional fields if provided
    $request_data->{editor} = $campaign->{editor} if defined $campaign->{editor};
    $request_data->{fileKey} = $campaign->{file_key} if defined $campaign->{file_key};
    $request_data->{scheduledTimestamp} = $campaign->{scheduled_timestamp} if defined $campaign->{scheduled_timestamp};
    $request_data->{scheduledTimezone} = $campaign->{scheduled_timezone} if defined $campaign->{scheduled_timezone};
    $request_data->{selectedList} = $campaign->{selected_list} if defined $campaign->{selected_list};
    $request_data->{listId} = $campaign->{list_id} if defined $campaign->{list_id};
    $request_data->{replaceContacts} = $campaign->{replace_contacts} if defined $campaign->{replace_contacts};
    $request_data->{emailTemplateId} = $campaign->{email_template_id} if defined $campaign->{email_template_id};
    $request_data->{fluxId} = $campaign->{flux_id} if defined $campaign->{flux_id};
    
    # Notify progress if callback provided
    if ($options && $options->{on_progress}) {
        $options->{on_progress}->('Sending email campaign');
    }
    
    # Make the API request to the email campaigns API
    my $response = $self->_custom_request('POST', '/campaigns', $request_data);
    
    # Notify progress if callback provided
    if ($options && $options->{on_progress}) {
        if ($response->{success}) {
            $options->{on_progress}->('Email campaign sent successfully');
        } else {
            $options->{on_progress}->('Email campaign sending failed');
        }
    }
    
    return $response;
}

=head2 send_single($first_name, $last_name, $email, $subject, $message, $sender_email, $reply_email, $sender_name, $title, \%options)

Send a single email to one recipient.

    my $response = $email->send_single(
        "John",
        "Doe",
        "john@example.com",
        "Welcome to Our Service",
        "<p>Hello John,</p><p>Thank you for signing up!</p>",
        "noreply@yourcompany.com",
        "support@yourcompany.com",
        "Your Company",
        "Welcome Email"
    );

Parameters:
- first_name: Recipient's first name
- last_name: Recipient's last name
- email: Recipient's email address
- subject: Email subject
- message: HTML message content
- sender_email: Sender's email address
- reply_email: Reply-to email address
- sender_name: Sender's name
- title: Campaign title
- options: Optional hash reference with settings

Returns a hash reference:
- success: 1 for success, 0 for failure
- data: Response data (on success)
- error: Error message (on failure)

=cut

sub send_single {
    my ($self, $first_name, $last_name, $email, $subject, $message, $sender_email, $reply_email, $sender_name, $title, $options) = @_;
    
    my $account = {
        first_name => $first_name,
        last_name => $last_name,
        email => $email
    };
    
    my $campaign = {
        subject => $subject,
        title => $title,
        message => $message,
        sender_email => $sender_email,
        reply_email => $reply_email,
        sender_name => $sender_name,
        accounts => [$account],
        campaign_type => 'EMAIL',
        add_to_list => 'noList',
        contact_input => 'accounts',
        from_type => 'single',
        senders => []
    };
    
    return $self->send_campaign($campaign, $options);
}

# Internal method to make a request to a custom API endpoint
sub _custom_request {
    my ($self, $method, $endpoint, $data) = @_;
    
    my $url = $self->{base_url} . $endpoint;
    my $request;
    
    # Create request based on method
    if (uc($method) eq 'GET') {
        $request = HTTP::Request::Common::GET($url);
    } elsif (uc($method) eq 'POST') {
        $request = HTTP::Request::Common::POST($url);
        if ($data) {
            $request->content($self->{ccai}->{json}->encode($data));
        }
    } elsif (uc($method) eq 'PUT') {
        $request = HTTP::Request::Common::PUT($url);
        if ($data) {
            $request->content($self->{ccai}->{json}->encode($data));
        }
    } elsif (uc($method) eq 'DELETE') {
        $request = HTTP::Request::Common::DELETE($url);
    } else {
        return {
            success => 0,
            error => "Unsupported HTTP method: $method"
        };
    }
    
    # Set headers
    $request->header('Authorization' => "Bearer " . $self->{ccai}->get_api_key());
    $request->header('Content-Type' => 'application/json');
    $request->header('Accept' => '*/*');
    $request->header('ClientId' => $self->{ccai}->get_client_id());
    $request->header('AccountId' => $self->{ccai}->get_client_id());
    
    # Make the request
    my $response = $self->{ccai}->{ua}->request($request);
    
    if ($response->is_success) {
        my $response_data;
        eval {
            $response_data = $self->{ccai}->{json}->decode($response->content);
        };
        if ($@) {
            return {
                success => 0,
                error => "Failed to parse JSON response: $@"
            };
        }
        
        return {
            success => 1,
            data => $response_data
        };
    } else {
        my $error_msg = "API Error: " . $response->status_line;
        if ($response->content) {
            $error_msg .= " - " . $response->content;
        }
        
        return {
            success => 0,
            error => $error_msg
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

=cut
