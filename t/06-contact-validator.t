#!/usr/bin/env perl

# Email validation with Amazon SES. The responses in t/fixtures/contact-validator were recorded from the
# contact-validator API. The CCAI client is replaced by a stub that answers like CCAI::request does: it returns
# { success => 1, data => <decoded JSON> } for a 2xx and { success => 0, error => "API Error: <status line> - <body>" }
# for any other status.

use strict;
use warnings;
use 5.016;

use Test::More;
use JSON::PP;
use File::Basename qw(dirname);
use File::Spec;
use lib File::Spec->catdir(dirname(__FILE__), '..', 'lib');

use CCAI::ContactValidator;

my $fixtures = File::Spec->catdir(dirname(__FILE__), 'fixtures', 'contact-validator');

sub recorded_text {
    my ($name) = @_;
    open my $fh, '<', File::Spec->catfile($fixtures, "$name.json") or die "Cannot read fixture $name: $!";
    local $/;
    my $text = <$fh>;
    close $fh;
    return $text;
}

sub recorded { return decode_json(recorded_text($_[0])) }

# The stub client: answers the next queued response and remembers what it was asked
package StubCCAI;

sub new {
    my ($class, @responses) = @_;
    return bless { responses => [@responses], calls => [] }, $class;
}

sub request {
    my ($self, $method, $endpoint, $data) = @_;
    push @{ $self->{calls} }, { method => $method, endpoint => $endpoint, data => $data };
    return shift @{ $self->{responses} };
}

package main;

sub replying_with {
    my ($fixture) = @_;
    return { success => 1, data => recorded($fixture) };
}

sub failing_with {
    my ($status_line, $fixture) = @_;
    return { success => 0, error => "API Error: $status_line - " . recorded_text($fixture) };
}

sub validator_for {
    my $ccai = StubCCAI->new(@_);
    return (CCAI::ContactValidator->new($ccai), $ccai);
}

# --- validate_email: the request ---------------------------------------------------------------------------------

{
    my ($cv, $ccai) = validator_for(replying_with('email-valid'));
    $cv->validate_email('jane@example.com');

    is($ccai->{calls}[0]{method}, 'POST', 'validate_email posts');
    is($ccai->{calls}[0]{endpoint}, '/v1/contact-validator/email', 'validate_email uses the email endpoint');
    is_deeply($ccai->{calls}[0]{data}, { email => 'jane@example.com' }, 'validate_email sends the address');
}

# --- validate_email: the new fields ------------------------------------------------------------------------------

{
    my ($cv) = validator_for(replying_with('email-valid'));
    my $result = $cv->validate_email('jane@example.com');
    my $metadata = $result->{data}{metadata};

    ok($result->{success}, 'the call succeeds');
    is($result->{data}{status}, 'valid', 'status is valid');
    ok($metadata->{safe_to_send}, 'safe_to_send is still there');
    is($metadata->{ai_verdict}, 'valid', 'ai_verdict is still there');
    is($metadata->{verdict}, 'HIGH', 'the overall verdict');
    is_deeply(
        $metadata->{checks},
        {
            hasValidSyntax     => 'HIGH',
            hasValidDnsRecords => 'HIGH',
            mailboxExists      => 'HIGH',
            isRoleAddress      => 'LOW',
            isDisposable       => 'LOW',
            isRandomInput      => 'LOW',
        },
        'the six checks'
    );
    is($metadata->{validatedAt}, '2026-11-13T15:02:11Z', 'when SES checked the address');
    ok(!$metadata->{reused}, 'a new check is not reused');
}

{
    my ($cv) = validator_for(replying_with('email-reused'));
    ok($cv->validate_email('jane@example.com')->{data}{metadata}{reused}, 'says when the result is a saved check');
}

{
    my ($cv) = validator_for(replying_with('email-risky-disposable'));
    my $result = $cv->validate_email('temp@mailinator.com');
    is($result->{data}{status}, 'risky', 'a disposable address is risky');
    ok(!$result->{data}{metadata}{safe_to_send}, 'and is not safe to send');
    is($result->{data}{metadata}{checks}{isDisposable}, 'HIGH', 'its disposable check is HIGH');
}

{
    my ($cv) = validator_for(replying_with('email-invalid-low'));
    my $result = $cv->validate_email('nobody@no-such-domain-example.xyz');
    is($result->{data}{status}, 'invalid', 'a LOW address is invalid');
    is($result->{data}{metadata}{verdict}, 'LOW', 'its verdict is LOW');
    is($result->{data}{metadata}{checks}{hasValidDnsRecords}, 'LOW', 'its domain does not accept mail');
}

{
    my ($cv) = validator_for(replying_with('email-rejected-format'));
    my $metadata = $cv->validate_email('not-an-email')->{data}{metadata};
    is($metadata->{verdict}, 'UNKNOWN', 'an address rejected before asking SES has an UNKNOWN verdict');
    is_deeply([ sort values %{ $metadata->{checks} } ], [ ('UNKNOWN') x 6 ], 'and six UNKNOWN checks');
    ok(!defined $metadata->{validatedAt}, 'and no date');
    is($metadata->{error}, 'Invalid email format', 'and the reason');
}

{
    my ($cv) = validator_for(replying_with('email-legacy'));
    my $result = $cv->validate_email('jane@example.com');
    my $metadata = $result->{data}{metadata};
    is($result->{data}{status}, 'valid', 'a response without the new fields is read as before');
    ok($metadata->{safe_to_send}, 'safe_to_send');
    is($metadata->{ai_verdict}, 'Mode: Sandbox', 'ai_verdict');
    ok(!exists $metadata->{$_}, "$_ is optional") for qw(verdict checks validatedAt reused);
}

# --- validate_email: errors --------------------------------------------------------------------------------------

{
    my ($cv) = validator_for(failing_with('403 Forbidden', 'error-403'));
    my $result = $cv->validate_email('jane@example.com');
    ok(!$result->{success}, '403: the call fails');
    like($result->{error}, qr/^API Error: 403 Forbidden/, '403: the status is in the error');
    like($result->{error}, qr/Email validation is not enabled for this account/, '403: and the reason');
}

{
    my ($cv) = validator_for(failing_with('502 Bad Gateway', 'error-502'));
    my $result = $cv->validate_email('jane@example.com');
    ok(!$result->{success}, '502: the call fails');
    like($result->{error}, qr/^API Error: 502 Bad Gateway/, '502: the status is in the error');
    like($result->{error}, qr/ses:GetEmailAddressInsights/, '502: and the message from AWS');
}

# --- validate_emails ---------------------------------------------------------------------------------------------

{
    my @emails = ('jane@example.com', 'temp@mailinator.com', 'bad@example.com');
    my ($cv, $ccai) = validator_for(replying_with('emails-bulk'));
    my $bulk = $cv->validate_emails(\@emails);

    is($ccai->{calls}[0]{endpoint}, '/v1/contact-validator/emails', 'validate_emails uses the bulk endpoint');
    is_deeply($ccai->{calls}[0]{data}, { emails => \@emails }, 'validate_emails sends the addresses');
    is_deeply($bulk->{data}{summary}, { total => 3, valid => 1, invalid => 1, risky => 1 }, 'the summary is as before');

    my ($reused, $risky, $failed) = @{ $bulk->{data}{results} };
    ok($reused->{metadata}{reused}, 'a reused result in a bulk response');
    is($reused->{metadata}{verdict}, 'HIGH', 'its verdict');
    is($risky->{metadata}{verdict}, 'MEDIUM', 'a risky result has its own verdict');
    is($risky->{metadata}{checks}{isDisposable}, 'HIGH', 'and its own checks');
    is($risky->{metadata}{validatedAt}, '2026-11-13T15:05:40Z', 'and its own date');
    is($failed->{status}, 'invalid', 'an address SES failed to check is invalid');
    is($failed->{metadata}{error}, 'The domain is not allowed', 'with the reason');
    ok(!exists $failed->{metadata}{$_}, "and no $_") for qw(verdict checks);
}

{
    my ($cv) = validator_for(failing_with('403 Forbidden', 'error-403'));
    my $result = $cv->validate_emails(['jane@example.com']);
    ok(!$result->{success}, 'validate_emails: 403 fails the call');
    like($result->{error}, qr/^API Error: 403/, 'validate_emails: the status is in the error');
}

# --- arguments ---------------------------------------------------------------------------------------------------

{
    my ($cv) = validator_for();
    eval { $cv->validate_email('') };
    like($@, qr/email is required/, 'an empty email is refused before any call');
    eval { $cv->validate_emails('jane@example.com') };
    like($@, qr/emails array reference is required/, 'emails must be an array reference');
}

done_testing();
