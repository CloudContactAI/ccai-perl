package CCAI::MMS;

use strict;
use warnings;
use 5.016;

use Carp qw(croak);
use File::Basename qw(basename);
use Digest::MD5;
use LWP::UserAgent;
use HTTP::Request::Common qw(GET PUT);
use JSON;

=head1 NAME

CCAI::MMS - MMS service for the CCAI API

=head1 SYNOPSIS

    my $mms = CCAI::MMS->new($ccai_instance);

    # Recommended: send with image file (auto-uploads, deduplicates via MD5)
    my $response = $mms->send_with_image(
        [{firstName => "John", lastName => "Doe", phone => "+15551234567"}],
        "Check out this image!",
        "MMS Campaign",
        "path/to/image.jpg"
    );

    # Single recipient shorthand
    my $response = $mms->send_single(
        "John", "Doe", "+15551234567",
        "Hello!", "MMS Test", "path/to/image.jpg"
    );

=head1 METHODS

=cut

sub new {
    my ($class, $ccai) = @_;
    croak "CCAI instance required" unless $ccai;
    bless { ccai => $ccai, ua => LWP::UserAgent->new(agent => "Faraday v2.12.2", timeout => 60) }, $class;
}

=head2 send(\@accounts, $message, $title, $file_key, $sender_phone)

Send an MMS with an already-uploaded image file key.

=cut

sub send {
    my ($self, $accounts, $message, $title, $file_key, $sender_phone) = @_;

    return { success => 0, error => 'At least one account is required' }
        unless $accounts && ref $accounts eq 'ARRAY' && @$accounts > 0;
    return { success => 0, error => 'Message is required' } unless $message;
    return { success => 0, error => 'Campaign title is required' } unless $title;
    return { success => 0, error => 'File key is required' } unless $file_key;

    for my $i (0 .. $#$accounts) {
        my $a = $accounts->[$i];
        return { success => 0, error => "firstName required for account $i" } unless $a->{firstName};
        return { success => 0, error => "lastName required for account $i" }  unless $a->{lastName};
        return { success => 0, error => "phone required for account $i" }     unless $a->{phone};
    }

    my $endpoint = "/clients/" . $self->{ccai}->get_client_id() . "/campaigns/direct";
    my $data = {
        pictureFileKey => $file_key,
        accounts       => $accounts,
        message        => $message,
        title          => $title,
    };
    $data->{senderPhone} = $sender_phone if $sender_phone;

    return $self->{ccai}->request('POST', $endpoint, $data);
}

=head2 send_single($first, $last, $phone, $message, $title, $file_key, $sender_phone)

Send MMS to a single recipient using an already-uploaded file key.

=cut

sub send_single {
    my ($self, $first, $last, $phone, $message, $title, $image_path, $sender_phone) = @_;
    return $self->send_with_image(
        [{ firstName => $first, lastName => $last, phone => $phone }],
        $message, $title, $image_path, $sender_phone
    );
}

=head2 send_with_image(\@accounts, $message, $title, $image_path, $sender_phone)

Complete MMS workflow: MD5-dedup check, get signed URL, upload image, send MMS.
Content type is auto-detected from the file extension.

=cut

sub send_with_image {
    my ($self, $accounts, $message, $title, $image_path, $sender_phone) = @_;

    return { success => 0, error => 'Image path is required' } unless $image_path;
    return { success => 0, error => "Image file not found: $image_path" } unless -f $image_path;

    my $client_id    = $self->{ccai}->get_client_id();
    my $md5          = $self->_md5_file($image_path);
    my $ext          = _extension($image_path);
    my $file_name    = "${md5}.${ext}";
    my $file_key     = "${client_id}/campaign/${file_name}";
    my $content_type = _content_type($ext);

    # Check if already uploaded (dedup)
    my $stored = $self->check_file_uploaded($file_key);
    unless ($stored && $stored->{success} && $stored->{data}{storedUrl}) {
        # Get signed URL and upload
        my $signed = $self->get_signed_url($file_name, $content_type);
        return $signed unless $signed->{success};

        my $upload = $self->upload_file($signed->{data}{signed_s3_url}, $image_path, $content_type);
        return $upload unless $upload->{success};
    }

    return $self->send($accounts, $message, $title, $file_key, $sender_phone);
}

=head2 get_signed_url($file_name, $file_type)

Get a signed S3 URL for uploading an image.

=cut

sub get_signed_url {
    my ($self, $file_name, $file_type) = @_;

    return { success => 0, error => 'File name is required' } unless $file_name;
    return { success => 0, error => 'File type is required' } unless $file_type;

    my $client_id     = $self->{ccai}->get_client_id();
    my $files_url     = $self->{ccai}->get_files_url();
    my $url           = "${files_url}/upload/url";
    my $file_base_path = "${client_id}/campaign";

    my $request_data = {
        fileName     => $file_name,
        fileType     => $file_type,
        fileBasePath => $file_base_path,
        publicFile   => JSON::true,
    };

    my $request = HTTP::Request::Common::POST($url);
    $request->content($self->{ccai}->{json}->encode($request_data));
    $request->header('Authorization' => "Bearer " . $self->{ccai}->get_api_key());
    $request->header('Content-Type'  => 'application/json');
    $request->header('Accept'        => '*/*');

    my $response = $self->{ua}->request($request);

    if ($response->is_success) {
        my $data;
        eval { $data = $self->{ccai}->{json}->decode($response->content) };
        return { success => 0, error => "Failed to parse response: $@" } if $@;

        my $file_key = "${client_id}/campaign/${file_name}";
        return {
            success => 1,
            data    => {
                signed_s3_url => $data->{signedS3Url},
                file_key      => $file_key,
            }
        };
    }

    return { success => 0, error => "API Error: " . $response->status_line . " - " . $response->content };
}

=head2 upload_file($signed_url, $file_path, $content_type)

Upload a file to S3 using a signed URL.

=cut

sub upload_file {
    my ($self, $signed_url, $file_path, $content_type) = @_;

    return { success => 0, error => 'Signed URL is required' }  unless $signed_url;
    return { success => 0, error => 'File path is required' }   unless $file_path;
    return { success => 0, error => "File not found: $file_path" } unless -f $file_path;
    return { success => 0, error => 'Content type is required' } unless $content_type;

    open my $fh, '<:raw', $file_path or return { success => 0, error => "Cannot read file: $!" };
    local $/;
    my $content = <$fh>;
    close $fh;

    my $request = PUT($signed_url);
    $request->content($content);
    $request->header('Content-Type' => $content_type);

    my $response = $self->{ua}->request($request);
    return $response->is_success
        ? { success => 1 }
        : { success => 0, error => "Upload failed: " . $response->status_line };
}

=head2 check_file_uploaded($file_key)

Check if a file has already been uploaded (deduplication).

=cut

sub check_file_uploaded {
    my ($self, $file_key) = @_;

    my $result = eval {
        $self->{ccai}->request('GET', "/clients/" . $self->{ccai}->get_client_id() . "/storedUrl?fileKey=${file_key}");
    };
    return undef if $@ || !$result || !$result->{success};

    my $stored_url = $result->{data}{storedUrl} // '';
    return $stored_url ? $result : undef;
}

# --- Private helpers ---

sub _md5_file {
    my ($self, $path) = @_;
    open my $fh, '<:raw', $path or croak "Cannot open $path: $!";
    my $md5 = Digest::MD5->new;
    $md5->addfile($fh);
    close $fh;
    return $md5->hexdigest;
}

sub _extension {
    my ($path) = @_;
    return ($path =~ /\.(\w+)$/) ? lc($1) : 'jpg';
}

sub _content_type {
    my ($ext) = @_;
    my %types = (jpg => 'image/jpeg', jpeg => 'image/jpeg', png => 'image/png', gif => 'image/gif');
    return $types{$ext} // 'image/jpeg';
}

1;

__END__

=head1 AUTHOR

CloudContactAI LLC

=head1 LICENSE

MIT License

Copyright (c) 2026 CloudContactAI LLC

=cut
