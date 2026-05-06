package CCAI::Campaign;

# Copyright (c) 2025 CloudContactAI LLC
# Licensed under the MIT License. See LICENSE in the project root for license information.

use strict;
use warnings;
use 5.016;

use Carp qw(croak);

=head1 NAME

CCAI::Campaign - Campaign management for the CCAI Compliance API (10DLC)

=head1 SYNOPSIS

    my $campaign = CCAI::Campaign->new($ccai_instance);

    my $res = $campaign->create({
        brandId           => 123,
        useCase           => 'MARKETING',
        description       => 'Test campaign for integration testing',
        messageFlow       => 'Users opt-in via our website form.',
        hasEmbeddedLinks  => JSON::false,
        hasEmbeddedPhone  => JSON::false,
        isAgeGated        => JSON::false,
        isDirectLending   => JSON::false,
        optInKeywords     => ['START', 'YES'],
        optInMessage      => 'You are now subscribed. Reply STOP to unsubscribe.',
        optInProofUrl     => 'https://example.com/optin',
        helpKeywords      => ['HELP', 'INFO'],
        helpMessage       => 'For help, reply HELP or contact support@example.com.',
        optOutKeywords    => ['STOP', 'CANCEL'],
        optOutMessage     => 'You have been unsubscribed. Reply STOP to opt out.',
        sampleMessages    => [
            'Hello! Reply STOP to unsubscribe.',
            'Your code is 123456. Reply HELP for assistance.',
        ],
    });

=cut

sub new {
    my ($class, $ccai) = @_;
    croak "CCAI instance required" unless $ccai;
    my $self = { ccai => $ccai };
    bless $self, $class;
    return $self;
}

=head2 create(\%params)

Creates a new 10DLC campaign.

=cut

sub create {
    my ($self, $params) = @_;
    my $err = _validate($params, 1);
    return { success => 0, error => $err } if $err;
    return $self->{ccai}->compliance_request('POST', '/v1/campaigns', $params);
}

=head2 get($campaign_id)

Retrieves a campaign by ID.

=cut

sub get {
    my ($self, $campaign_id) = @_;
    return { success => 0, error => 'campaignId is required' } unless $campaign_id;
    return $self->{ccai}->compliance_request('GET', "/v1/campaigns/$campaign_id");
}

=head2 list()

Retrieves all campaigns.

=cut

sub list {
    my ($self) = @_;
    return $self->{ccai}->compliance_request('GET', '/v1/campaigns');
}

=head2 update($campaign_id, \%params)

Updates an existing campaign.

=cut

sub update {
    my ($self, $campaign_id, $params) = @_;
    return { success => 0, error => 'campaignId is required' } unless $campaign_id;
    my $err = _validate($params, 0);
    return { success => 0, error => $err } if $err;
    return $self->{ccai}->compliance_request('PATCH', "/v1/campaigns/$campaign_id", $params);
}

=head2 delete($campaign_id)

Deletes a campaign by ID.

=cut

sub delete {
    my ($self, $campaign_id) = @_;
    return { success => 0, error => 'campaignId is required' } unless $campaign_id;
    return $self->{ccai}->compliance_request('DELETE', "/v1/campaigns/$campaign_id");
}

# ---------------------------------------------------------------------------
# Internal validation
# ---------------------------------------------------------------------------

sub _validate {
    my ($params, $is_create) = @_;
    return 'params hash required' unless $params && ref $params eq 'HASH';

    if ($is_create) {
        for my $field (qw(
            brandId useCase description messageFlow
            hasEmbeddedLinks hasEmbeddedPhone isAgeGated isDirectLending
            optInKeywords optInMessage optInProofUrl
            helpKeywords helpMessage
            optOutKeywords optOutMessage
            sampleMessages
        )) {
            return "$field is required"
                unless defined $params->{$field} && $params->{$field} ne '';
        }
    }

    if (defined $params->{sampleMessages}) {
        my $msgs = $params->{sampleMessages};
        return 'sampleMessages must be an array ref' unless ref $msgs eq 'ARRAY';
        return 'sampleMessages must contain between 2 and 5 messages'
            unless @$msgs >= 2 && @$msgs <= 5;

        my @opt_out_kws = ref($params->{optOutKeywords}) eq 'ARRAY'
            ? map { uc($_) } @{$params->{optOutKeywords}} : ('STOP');
        my @help_kws = ref($params->{helpKeywords}) eq 'ARRAY'
            ? map { uc($_) } @{$params->{helpKeywords}} : ('HELP');

        my $has_stop = grep {
            my $msg = uc($_);
            grep { $msg =~ /REPLY $_/ } @opt_out_kws
        } @$msgs;
        return "at least one sampleMessage must contain opt-out language (e.g. 'Reply STOP')"
            unless $has_stop;

        my $has_help = grep {
            my $msg = uc($_);
            grep { $msg =~ /REPLY $_/ } @help_kws
        } @$msgs;
        return "at least one sampleMessage must contain help language (e.g. 'Reply HELP')"
            unless $has_help;
    }

    if (defined $params->{optOutMessage} && defined $params->{optOutKeywords}) {
        my @opt_out_kws = ref($params->{optOutKeywords}) eq 'ARRAY'
            ? map { uc($_) } @{$params->{optOutKeywords}} : ('STOP');
        my $opt_out_msg = uc($params->{optOutMessage});
        my $has_kw = grep { $opt_out_msg =~ /$_/ } @opt_out_kws;
        return "optOutMessage must contain an opt-out keyword (e.g. 'STOP')" unless $has_kw;
    }

    if (defined $params->{useCase}) {
        my $use_case = uc($params->{useCase});
        if ($use_case eq 'MIXED' || $use_case eq 'LOW_VOLUME_MIXED') {
            my $subs = $params->{subUseCases} // [];
            return 'MIXED/LOW_VOLUME_MIXED campaigns require 2-3 subUseCases'
                unless ref $subs eq 'ARRAY' && @$subs >= 2 && @$subs <= 3;
        }
    }

    return undef;
}

1;

__END__

=head1 AUTHOR

CloudContactAI LLC

=head1 LICENSE

MIT License

Copyright (c) 2025 CloudContactAI LLC

=cut
