package CCAI::Brand;

# Copyright (c) 2025 CloudContactAI LLC
# Licensed under the MIT License. See LICENSE in the project root for license information.

use strict;
use warnings;
use 5.016;

use Carp qw(croak);

=head1 NAME

CCAI::Brand - Brand management for the CCAI Compliance API (10DLC)

=head1 SYNOPSIS

    my $brand = CCAI::Brand->new($ccai_instance);

    my $res = $brand->create({
        legalCompanyName   => 'My Company LLC',
        dba                => 'My Company',
        entityType         => 'PRIVATE_PROFIT',
        taxId              => '123456789',
        taxIdCountry       => 'US',
        country            => 'US',
        verticalType       => 'TECHNOLOGY',
        websiteUrl         => 'https://example.com',
        street             => '123 Main St',
        city               => 'Miami',
        state              => 'FL',
        postalCode         => '33101',
        contactFirstName   => 'John',
        contactLastName    => 'Doe',
        contactEmail       => 'john@example.com',
        contactPhone       => '+13055551234',
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

Creates a new 10DLC brand.

=cut

sub create {
    my ($self, $params) = @_;
    my $err = _validate($params, 1);
    return { success => 0, error => $err } if $err;
    return $self->{ccai}->compliance_request('POST', '/v1/brands', $params);
}

=head2 get($brand_id)

Retrieves a brand by ID.

=cut

sub get {
    my ($self, $brand_id) = @_;
    return { success => 0, error => 'brandId is required' } unless $brand_id;
    return $self->{ccai}->compliance_request('GET', "/v1/brands/$brand_id");
}

=head2 list()

Retrieves all brands.

=cut

sub list {
    my ($self) = @_;
    return $self->{ccai}->compliance_request('GET', '/v1/brands');
}

=head2 update($brand_id, \%params)

Updates an existing brand.

=cut

sub update {
    my ($self, $brand_id, $params) = @_;
    return { success => 0, error => 'brandId is required' } unless $brand_id;
    my $err = _validate($params, 0);
    return { success => 0, error => $err } if $err;
    return $self->{ccai}->compliance_request('PATCH', "/v1/brands/$brand_id", $params);
}

=head2 delete($brand_id)

Deletes a brand by ID.

=cut

sub delete {
    my ($self, $brand_id) = @_;
    return { success => 0, error => 'brandId is required' } unless $brand_id;
    return $self->{ccai}->compliance_request('DELETE', "/v1/brands/$brand_id");
}

# ---------------------------------------------------------------------------
# Internal validation
# ---------------------------------------------------------------------------

sub _validate {
    my ($params, $is_create) = @_;
    return 'params hash required' unless $params && ref $params eq 'HASH';

    if ($is_create) {
        my @required = qw(
            legalCompanyName entityType taxId taxIdCountry country
            verticalType websiteUrl street city state postalCode
            contactFirstName contactLastName contactEmail contactPhone
        );
        for my $field (@required) {
            return "$field is required" unless defined $params->{$field} && $params->{$field} ne '';
        }
    }

    if (defined $params->{entityType} && uc($params->{entityType}) eq 'PUBLIC_PROFIT') {
        return 'stockSymbol is required for PUBLIC_PROFIT entity type'
            unless defined $params->{stockSymbol} && $params->{stockSymbol} ne '';
        return 'stockExchange is required for PUBLIC_PROFIT entity type'
            unless defined $params->{stockExchange} && $params->{stockExchange} ne '';
    }

    if (defined $params->{websiteUrl}) {
        return 'websiteUrl must start with http:// or https://'
            unless $params->{websiteUrl} =~ m{^https?://};
    }

    if (defined $params->{contactEmail}) {
        return 'contactEmail must be a valid email address'
            unless $params->{contactEmail} =~ m{^[^\s\@]+\@[^\s\@]+\.[^\s\@]+$};
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
