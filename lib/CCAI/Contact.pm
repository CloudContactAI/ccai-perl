package CCAI::Contact;

use strict;
use warnings;
use 5.016;

use Carp qw(croak);

=head1 NAME

CCAI::Contact - Contact preference management for the CCAI API

=head1 SYNOPSIS

    my $contact = CCAI::Contact->new($ccai_instance);

    # Opt a contact out of SMS messages
    my $response = $contact->set_do_not_text(1, { phone => '+15551234567' });

    # Opt a contact back in
    my $response = $contact->set_do_not_text(0, { phone => '+15551234567' });

    # Use contact ID instead of phone
    my $response = $contact->set_do_not_text(1, { contact_id => 'abc123' });

=head1 DESCRIPTION

CCAI::Contact handles contact preference management for the Cloud Contact AI platform,
including opt-out and opt-in for SMS messaging.

=head1 METHODS

=head2 new($ccai)

Creates a new Contact service instance.

    my $contact = CCAI::Contact->new($ccai_instance);

=cut

sub new {
    my ($class, $ccai) = @_;

    croak "CCAI instance required" unless $ccai;

    my $self = { ccai => $ccai };
    bless $self, $class;
    return $self;
}

=head2 set_do_not_text($do_not_text, \%options)

Set the do-not-text preference for a contact.

    # Opt out
    my $response = $contact->set_do_not_text(1, { phone => '+15551234567' });

    # Opt in
    my $response = $contact->set_do_not_text(0, { contact_id => 'abc123' });

Parameters:
- do_not_text: 1 to opt out, 0 to opt in
- options: Hash reference with at least one of:
  - phone: Phone number in E.164 format
  - contact_id: Contact ID

Returns a hash reference:
- success: 1 for success, 0 for failure
- data: Response data (on success)
- error: Error message (on failure)

=cut

sub set_do_not_text {
    my ($self, $do_not_text, $options) = @_;

    $options //= {};

    unless (defined $do_not_text) {
        return { success => 0, error => 'do_not_text value is required' };
    }

    unless ($options->{phone} || $options->{contact_id}) {
        return { success => 0, error => 'Either phone or contact_id is required' };
    }

    my $payload = {
        clientId  => $self->{ccai}->get_client_id(),
        doNotText => $do_not_text ? JSON::true : JSON::false,
    };

    $payload->{phone}     = $options->{phone}      if defined $options->{phone};
    $payload->{contactId} = $options->{contact_id} if defined $options->{contact_id};

    return $self->{ccai}->request('PUT', '/account/do-not-text', $payload);
}

1;

__END__

=head1 AUTHOR

CloudContactAI LLC

=head1 LICENSE

MIT License

Copyright (c) 2026 CloudContactAI LLC

=cut
