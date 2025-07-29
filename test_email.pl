#!/usr/bin/env perl

use strict;
use warnings;
use 5.016;

use lib 'lib';
use CCAI;

# Create a CCAI client for test environment
my $ccai = CCAI->new({
    client_id => '1231',
    api_key   => 'eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJhbmRyZWFzQGFsbGNvZGUuY29tIiwiaXNzIjoiY2xvdWRjb250YWN0IiwibmJmIjoxNzUyMDg5MDk2LCJpYXQiOjE3NTIwODkwOTYsInJvbGUiOiJVU0VSIiwiY2xpZW50SWQiOjEyMzEsImlkIjoxMjIzLCJ0eXBlIjoiQVBJX0tFWSIsImtleV9yYW5kb21faWQiOiIzNTAxZjVmNC0zOWYyLTRjYzctYTk2Yi04ZDkyZjVlMjM5ZGUifQ.XjtDPpyYUJNJjLrpM1pdQ4Sqk90eaagqzPX2v1gwHDP1wOV4fTbB44UGDRXtWyGvN-Fz7o84_Ab-VlAjNCyEmXcDzmzscnwFSbqiZrWLAM_W3Mutd36vArl9QSG_osuYdf9T2wmAduUZu2bcnvKHdBbEaBUalJSSUoHwHsMBX3w',
    base_url  => 'https://core-test-cloudcontactai.allcode.com/api',
    email_url => 'https://email-campaigns-test-cloudcontactai.allcode.com',
    auth_url  => 'https://auth-test-cloudcontactai.allcode.com'
});

print "Testing email functionality with test environment...\n";

# Send a single email
my $response = $ccai->email->send_single(
    "Andreas",                                 # First name
    "Test",                                    # Last name
    "andreas@allcode.com",                     # Email address
    "Test Email from CCAI Perl Client",       # Subject
    "<p>Hello Andreas,</p><p>This is a test email from the CCAI Perl client using the test environment.</p><p>Best regards,<br>CCAI Team</p>",  # HTML message content
    "noreply@allcode.com",                     # Sender email
    "support@allcode.com",                     # Reply-to email
    "CCAI Test",                               # Sender name
    "Test Email Campaign"                      # Campaign title
);

if ($response->{success}) {
    print "✓ Email sent successfully!\n";
    print "Response data:\n";
    use Data::Dumper;
    print Dumper($response->{data});
} else {
    print "✗ Error sending email: " . $response->{error} . "\n";
}