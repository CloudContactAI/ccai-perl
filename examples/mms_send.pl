#!/usr/bin/env perl

use strict;
use warnings;
use 5.016;

use lib '../lib', 'lib';
use CCAI;
use CCAI::EnvLoader;

# Load environment variables from .env file
CCAI::EnvLoader->load();

sub main {
    my ($client_id, $api_key);
    eval { ($client_id, $api_key) = CCAI::EnvLoader->get_ccai_credentials() };
    if ($@) {
        print "❌ Configuration Error:\n$@\n";
        return;
    }

    print "🔧 Using credentials from environment variables\n";
    print "Client ID: " . substr($client_id, 0, 8) . "...\n\n";

    my $ccai = CCAI->new({
        client_id            => $client_id,
        api_key              => $api_key,
        use_test_environment => 1,
    });

    my @accounts = (
        {
            firstName => "John",
            lastName  => "Doe",
            phone     => "+14152440933"
        }
    );

    print "Sending MMS with CloudContactAI.png...\n";

    my $response = $ccai->mms->send_with_image(
        \@accounts,
        "Hello \${firstName}, check out this CCAI image!",
        "Perl MMS Test Campaign",
        "CloudContactAI.png"
    );

    if ($response->{success}) {
        print "✓ MMS sent successfully!\n";
        print "Campaign ID: " . ($response->{data}->{campaign_id} // 'N/A') . "\n";
    } else {
        print "✗ Error sending MMS: " . $response->{error} . "\n";
    }
}

main() unless caller;

1;
