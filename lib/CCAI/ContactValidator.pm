package CCAI::ContactValidator;

use strict;
use warnings;
use 5.016;

use Carp qw(croak);

=head1 NAME

CCAI::ContactValidator - Email and phone contact validation for the CCAI API

=head1 SYNOPSIS

    my $cv = CCAI::ContactValidator->new($ccai_instance);

    # Validate a single email
    my $result = $cv->validate_email('user@example.com');

    # Validate multiple emails (up to 50)
    my $bulk = $cv->validate_emails(['a@b.com', 'x@y.com']);

    # Validate a phone number
    my $phone = $cv->validate_phone('+15551234567', { country_code => 'US' });

    # Validate multiple phones (up to 50)
    my $phones = $cv->validate_phones([
        { phone => '+15551234567' },
        { phone => '+573007590979', countryCode => 'CO' }
    ]);

=head1 DESCRIPTION

CCAI::ContactValidator provides email and phone number validation by proxying to
the CloudContactAI contact validator endpoints.

=head1 METHODS

=head2 new($ccai)

Creates a new ContactValidator service instance.

=cut

sub new {
    my ($class, $ccai) = @_;
    croak "CCAI instance required" unless $ccai;
    my $self = { ccai => $ccai };
    bless $self, $class;
    return $self;
}

=head2 validate_email($email)

Validate a single email address.

    my $result = $cv->validate_email('user@example.com');

Returns a hash reference with success/data or success/error keys.

=cut

sub validate_email {
    my ($self, $email) = @_;
    croak "email is required" unless defined $email && $email ne '';
    return $self->{ccai}->request('POST', '/v1/contact-validator/email', { email => $email });
}

=head2 validate_emails(\@emails)

Validate multiple email addresses (up to 50).

    my $result = $cv->validate_emails(['a@b.com', 'x@y.com']);

=cut

sub validate_emails {
    my ($self, $emails) = @_;
    croak "emails array reference is required" unless ref $emails eq 'ARRAY';
    return $self->{ccai}->request('POST', '/v1/contact-validator/emails', { emails => $emails });
}

=head2 validate_phone($phone, \%options)

Validate a single phone number in E.164 format.

    my $result = $cv->validate_phone('+15551234567');
    my $result = $cv->validate_phone('+15551234567', { country_code => 'US' });

=cut

sub validate_phone {
    my ($self, $phone, $options) = @_;
    croak "phone is required" unless defined $phone && $phone ne '';
    $options //= {};
    my $payload = { phone => $phone };
    $payload->{countryCode} = $options->{country_code} if defined $options->{country_code};
    return $self->{ccai}->request('POST', '/v1/contact-validator/phone', $payload);
}

=head2 validate_phones(\@phones)

Validate multiple phone numbers (up to 50).

    my $result = $cv->validate_phones([
        { phone => '+15551234567' },
        { phone => '+15559876543', countryCode => 'US' }
    ]);

=cut

sub validate_phones {
    my ($self, $phones) = @_;
    croak "phones array reference is required" unless ref $phones eq 'ARRAY';
    return $self->{ccai}->request('POST', '/v1/contact-validator/phones', { phones => $phones });
}

1;

__END__

=head1 AUTHOR

CloudContactAI LLC

=head1 LICENSE

MIT License

Copyright (c) 2025 CloudContactAI LLC

=cut
