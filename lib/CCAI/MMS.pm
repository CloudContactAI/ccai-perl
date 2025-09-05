package CCAI::MMS;

use strict;
use warnings;
use 5.016;

use Carp qw(croak);
use File::Basename qw(basename);
use File::Slurp qw(read_file);
use LWP::UserAgent;
use HTTP::Request::Common qw(PUT);

=head1 NAME

CCAI::MMS - MMS service for the CCAI API

=head1 SYNOPSIS

    my $mms = CCAI::MMS->new($ccai_instance);
    
    my $response = $mms->send_with_image(
        'path/to/image.jpg',
        'image/jpeg',
        [{
            firstName => "John",
            lastName  => "Doe",
            phone      => "+15551234567"
        }],
        "Hello \${firstName}, check out this image!",
        "MMS Campaign"
    );

=head1 DESCRIPTION

CCAI::MMS handles sending MMS messages through the Cloud Contact AI platform.

=head1 METHODS

=head2 new($ccai)

Creates a new MMS service instance.

    my $mms = CCAI::MMS->new($ccai_instance);

=cut

sub new {
    my ($class, $ccai) = @_;
    
    croak "CCAI instance required" unless $ccai;
    
    my $self = {
        ccai => $ccai,
        ua   => LWP::UserAgent->new(timeout => 60)
    };
    
    bless $self, $class;
    return $self;
}

=head2 get_signed_url($file_name, $file_type, $file_base_path, $public_file)

Get a signed S3 URL to upload an image file.

    my $response = $mms->get_signed_url(
        'image.jpg',
        'image/jpeg',
        'client123/campaign',  # optional
        1                      # optional, default true
    );

Parameters:
- file_name: Name of the file to upload
- file_type: MIME type of the file
- file_base_path: Base path for the file in S3 (optional, defaults to clientId/campaign)
- public_file: Whether the file should be public (optional, defaults to true)

Returns a hash reference:
- success: 1 for success, 0 for failure
- data: Response data with signed_s3_url and file_key (on success)
- error: Error message (on failure)

=cut

sub get_signed_url {
    my ($self, $file_name, $file_type, $file_base_path, $public_file) = @_;
    
    unless ($file_name) {
        return {
            success => 0,
            error   => 'File name is required'
        };
    }
    
    unless ($file_type) {
        return {
            success => 0,
            error   => 'File type is required'
        };
    }
    
    # Set defaults
    $file_base_path //= $self->{ccai}->get_client_id() . '/campaign';
    $public_file = 1 unless defined $public_file;
    
    # Use the correct files API endpoint
    my $url = 'https://files.cloudcontactai.com/upload/url';
    
    my $request_data = {
        fileName      => $file_name,
        fileType      => $file_type,
        fileBasePath  => $file_base_path,
        publicFile    => $public_file ? JSON::true : JSON::false
    };
    
    # Create a separate UA for files API to avoid Cloudflare blocks
    my $files_ua = LWP::UserAgent->new(
        agent   => "Faraday v2.12.2",
        timeout => 60
    );
    
    # Make direct request to files API
    my $request = HTTP::Request::Common::POST($url);
    $request->content($self->{ccai}->{json}->encode($request_data));
    $request->header('Authorization' => "Bearer " . $self->{ccai}->get_api_key());
    $request->header('Content-Type'  => 'application/json');
    $request->header('Accept'        => '*/*');
    
    my $response = $files_ua->request($request);
    
    if ($response->is_success) {
        my $response_data;
        eval {
            $response_data = $self->{ccai}->{json}->decode($response->content);
        };
        if ($@) {
            return {
                success => 0,
                error   => "Failed to parse JSON response: $@"
            };
        }
        
        # Override fileKey like Ruby does
        $response_data->{file_key} = $self->{ccai}->get_client_id() . "/campaign/" . $file_name;
        
        return {
            success => 1,
            data    => {
                signed_s3_url => $response_data->{signedS3Url},
                file_key      => $response_data->{file_key}
            }
        };
    } else {
        return {
            success => 0,
            error   => "API Error: " . $response->status_line . " - " . $response->content
        };
    }
}

=head2 upload_file($signed_url, $file_path, $content_type)

Upload a file to S3 using a signed URL.

    my $response = $mms->upload_file(
        'https://s3.amazonaws.com/bucket/signed-url',
        'path/to/image.jpg',
        'image/jpeg'
    );

Parameters:
- signed_url: The signed S3 URL from get_signed_url
- file_path: Local path to the file to upload
- content_type: MIME type of the file

Returns a hash reference:
- success: 1 for success, 0 for failure
- error: Error message (on failure)

=cut

sub upload_file {
    my ($self, $signed_url, $file_path, $content_type) = @_;
    
    unless ($signed_url) {
        return {
            success => 0,
            error   => 'Signed URL is required'
        };
    }
    
    unless ($file_path) {
        return {
            success => 0,
            error   => 'File path is required'
        };
    }
    
    unless (-f $file_path) {
        return {
            success => 0,
            error   => "File not found: $file_path"
        };
    }
    
    unless ($content_type) {
        return {
            success => 0,
            error   => 'Content type is required'
        };
    }
    
    # Read file content
    my $file_content;
    eval {
        $file_content = read_file($file_path, { binmode => ':raw' });
    };
    if ($@) {
        return {
            success => 0,
            error   => "Failed to read file: $@"
        };
    }
    
    # Create PUT request
    my $request = PUT($signed_url);
    $request->content($file_content);
    $request->header('Content-Type' => $content_type);
    
    # Upload file
    my $response = $self->{ua}->request($request);
    
    if ($response->is_success) {
        return {
            success => 1
        };
    } else {
        return {
            success => 0,
            error   => "Upload failed: " . $response->status_line
        };
    }
}

=head2 send_mms(\@accounts, $message, $title, $file_key, \%options)

Send an MMS message with an uploaded image.

    my $response = $mms->send_mms(
        [{
            firstName => "John",
            lastName  => "Doe",
            phone      => "+15551234567"
        }],
        "Hello \${firstName}, check out this image!",
        "MMS Campaign",
        "client123/campaign/image.jpg"
    );

Parameters:
- accounts: Array reference of recipient hash references
- message: The message to send (can include ${firstName} and ${lastName} variables)
- title: Campaign title
- file_key: The S3 file key from the upload process
- options: Optional hash reference with settings

Returns a hash reference:
- success: 1 for success, 0 for failure
- data: Response data (on success)
- error: Error message (on failure)

=cut

sub send_mms {
    my ($self, $accounts, $message, $title, $file_key, $options) = @_;
    
    # Validate inputs (similar to SMS validation)
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
    
    unless ($file_key) {
        return {
            success => 0,
            error   => 'File key is required'
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
        $options->{on_progress}->('Preparing to send MMS');
    }
    
    my $endpoint = "/clients/" . $self->{ccai}->get_client_id() . "/campaigns/direct";
    
    my $campaign_data = {
        pictureFileKey => $file_key,
        accounts       => $accounts,
        message        => $message,
        title          => $title
    };
    
    # Notify progress if callback provided
    if ($options && $options->{on_progress}) {
        $options->{on_progress}->('Sending MMS');
    }
    
    # Make the API request
    my $response = $self->{ccai}->request('POST', $endpoint, $campaign_data);
    
    # Notify progress if callback provided
    if ($options && $options->{on_progress}) {
        if ($response->{success}) {
            $options->{on_progress}->('MMS sent successfully');
        } else {
            $options->{on_progress}->('MMS sending failed');
        }
    }
    
    return $response;
}

=head2 send_with_image($image_path, $content_type, \@accounts, $message, $title, \%options)

Complete MMS workflow: get signed URL, upload image, and send MMS in one step.

    my $response = $mms->send_with_image(
        'path/to/image.jpg',
        'image/jpeg',
        [{
            firstName => "John",
            lastName  => "Doe",
            phone      => "+15551234567"
        }],
        "Hello \${firstName}, check out this image!",
        "MMS Campaign Example",
        {
            timeout     => 60000,
            on_progress => sub { print "Progress: $_[0]\n" }
        }
    );

Parameters:
- image_path: Local path to the image file
- content_type: MIME type of the image
- accounts: Array reference of recipient hash references
- message: The message to send (can include ${firstName} and ${lastName} variables)
- title: Campaign title
- options: Optional hash reference with settings

Returns a hash reference:
- success: 1 for success, 0 for failure
- data: Response data (on success)
- error: Error message (on failure)

=cut

sub send_with_image {
    my ($self, $image_path, $content_type, $accounts, $message, $title, $options) = @_;
    
    unless ($image_path) {
        return {
            success => 0,
            error   => 'Image path is required'
        };
    }
    
    unless (-f $image_path) {
        return {
            success => 0,
            error   => "Image file not found: $image_path"
        };
    }
    
    unless ($content_type) {
        return {
            success => 0,
            error   => 'Content type is required'
        };
    }
    
    # Notify progress if callback provided
    if ($options && $options->{on_progress}) {
        $options->{on_progress}->('Getting signed URL for image upload');
    }
    
    # Step 1: Get signed URL
    my $file_name = basename($image_path);
    my $signed_url_response = $self->get_signed_url($file_name, $content_type);
    
    unless ($signed_url_response->{success}) {
        return $signed_url_response;
    }
    
    my $signed_url = $signed_url_response->{data}->{signed_s3_url};
    my $file_key = $signed_url_response->{data}->{file_key};
    
    # Notify progress if callback provided
    if ($options && $options->{on_progress}) {
        $options->{on_progress}->('Uploading image to S3');
    }
    
    # Step 2: Upload image
    my $upload_response = $self->upload_file($signed_url, $image_path, $content_type);
    
    unless ($upload_response->{success}) {
        return $upload_response;
    }
    
    # Notify progress if callback provided
    if ($options && $options->{on_progress}) {
        $options->{on_progress}->('Image uploaded, sending MMS');
    }
    
    # Step 3: Send MMS
    return $self->send_mms($accounts, $message, $title, $file_key, $options);
}

1;

__END__

=head1 AUTHOR

CloudContactAI LLC

=head1 LICENSE

MIT License

Copyright (c) 2025 CloudContactAI LLC

=cut
