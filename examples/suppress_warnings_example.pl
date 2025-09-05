#!/usr/bin/env perl

use strict;
use warnings;
use 5.016;

# Suppress LWP Content-Length warnings
BEGIN {
    # Method 1: Suppress specific LWP warnings
    $SIG{__WARN__} = sub {
        my $warning = shift;
        # Only suppress the specific Content-Length warning
        return if $warning =~ /Content-Length header value was wrong, fixed/;
        warn $warning;
    };
}

# Alternative Method 2: Set LWP debug level (uncomment to use instead)
# use LWP::Debug qw(-);  # Disable all LWP debug output

use lib '../lib', 'lib';
use CCAI;
use CCAI::EnvLoader;
use JSON;

# Load environment variables from .env file
CCAI::EnvLoader->load();

sub main {
    # Get credentials from environment variables
    my ($client_id, $api_key);
    
    eval {
        ($client_id, $api_key) = CCAI::EnvLoader->get_ccai_credentials();
    };
    if ($@) {
        print "❌ Configuration Error:\n";
        print $@;
        print "\nPlease create a .env file with your CCAI credentials.\n";
        print "You can copy .env.example to .env and fill in your credentials.\n";
        return;
    }
    
    print "🔧 Using credentials from environment variables (warnings suppressed)\n";
    print "Client ID: " . substr($client_id, 0, 8) . "...\n";
    print "API Key: " . substr($api_key, 0, 8) . "...\n\n";

    # Initialize the client
    my $ccai = CCAI->new({
        client_id => $client_id,
        api_key   => $api_key
    });

    print "Sending SMS with customData (no Content-Length warnings)\n";
    print "=" x 60 . "\n";
    
    my @accounts = (
        {
            firstName => "John",
            lastName  => "Doe",
            phone      => "+14155551212",
            customData => {
                order_id => "ORD-12345",
                customer_type => "premium",
                purchase_amount => 299.99
            }
        }
    );

    my $response = $ccai->sms->send(
        \@accounts,
        "Hello \${firstName} \${lastName}, your order has been confirmed!",
        "Test Campaign (No Warnings)"
    );

    if ($response->{success}) {
        print "✅ SMS sent successfully!\n";
        print "Campaign ID: " . ($response->{data}->{campaign_id} // 'N/A') . "\n";
    } else {
        print "❌ Error sending SMS: " . $response->{error} . "\n";
    }

    print "\nNote: Content-Length warnings have been suppressed.\n";
}

# Run the example
main() unless caller;

1;
