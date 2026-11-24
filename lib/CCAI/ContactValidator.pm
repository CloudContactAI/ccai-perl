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

Validate a single email address with Amazon SES. Nothing is sent to the address.

    my $result = $cv->validate_email('user@example.com');

Returns a hash reference with C<success> and C<data>, or C<success> (false) and C<error>. C<data> has
C<contactField>, C<type>, C<status> and C<metadata>. Besides C<safe_to_send> and C<ai_verdict>, C<metadata> has these
optional keys. They are missing when the account does not have Email Address Validation, or the address was not
checked:

=over 4

=item C<verdict>

The overall verdict: C<HIGH>, C<MEDIUM>, C<LOW> or C<UNKNOWN>.

=item C<checks>

A hash reference with six checks, each with its own verdict: C<hasValidSyntax>, C<hasValidDnsRecords>,
C<mailboxExists> (good value C<HIGH>), and C<isRoleAddress>, C<isDisposable>, C<isRandomInput> (good value C<LOW>).

=item C<validatedAt>

When SES checked the address (ISO 8601). C<undef> when the address was rejected without a check.

=item C<reused>

True when the result is a saved check from the last 30 days, instead of a new one.

=item C<error>

Why the address was rejected or could not be checked, for example C<Invalid email format>.

=back

    if ($result->{success}) {
        my $metadata = $result->{data}{metadata};
        print "$metadata->{verdict}\n";                # HIGH
        print "$metadata->{checks}{isDisposable}\n";    # LOW
    }

A failed call has C<< $result->{error} >> set to C<API Error: E<lt>status lineE<gt> - E<lt>bodyE<gt>>. A 403 means Email
Address Validation is not enabled for the account. A 502 means SES rejected the check: the body has the AWS message,
and if the account uses its own AWS keys for email, the IAM user needs the C<ses:GetEmailAddressInsights> permission.

=cut

sub validate_email {
    my ($self, $email) = @_;
    croak "email is required" unless defined $email && $email ne '';
    return $self->{ccai}->request('POST', '/v1/contact-validator/email', { email => $email });
}

=head2 validate_emails(\@emails)

Validate multiple email addresses with Amazon SES (up to 10 per request).

    my $result = $cv->validate_emails(['a@b.com', 'x@y.com']);

C<< $result->{data}{results} >> has one item per address, shaped like the C<data> of L</validate_email($email)>. An
address that SES fails to check comes back as C<invalid>, with the reason in C<< metadata->{error} >>. A 403 fails the
whole call, as for a single address.

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
