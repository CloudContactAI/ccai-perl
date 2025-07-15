#!/usr/bin/env perl

use strict;
use warnings;
use lib 'lib';

print "CCAI Perl Client - SSL Verification\n";
print "=" x 40 . "\n";

# Test SSL configuration
my $ssl_ok = 0;

print "1. Checking Mozilla::CA module... ";
eval {
    require Mozilla::CA;
    my $ca_file = Mozilla::CA::SSL_ca_file();
    if (-f $ca_file) {
        print "✓ OK ($ca_file)\n";
        $ssl_ok = 1;
    } else {
        print "✗ CA file not found\n";
    }
};
if ($@) {
    print "✗ Not installed\n";
    print "   Install with: cpanm Mozilla::CA\n";
}

print "2. Checking HTTPS support... ";
eval {
    require LWP::Protocol::https;
    print "✓ OK\n";
};
if ($@) {
    print "✗ Not available\n";
    print "   Install with: cpanm LWP::Protocol::https\n";
}

print "3. Testing CCAI client creation... ";
eval {
    require CCAI;
    my $ccai = CCAI->new({
        client_id => 'test',
        api_key   => 'test'
    });
    print "✓ OK\n";
};
if ($@) {
    print "✗ Failed: $@\n";
}

print "4. Testing HTTPS connection... ";
eval {
    require LWP::UserAgent;
    my $ua = LWP::UserAgent->new(timeout => 10);
    my $response = $ua->get('https://httpbin.org/get');
    if ($response->is_success) {
        print "✓ OK\n";
    } else {
        print "✗ Failed: " . $response->status_line . "\n";
    }
};
if ($@) {
    print "✗ Error: $@\n";
}

print "\n";
if ($ssl_ok) {
    print "✅ SSL configuration looks good!\n";
    print "You should be able to run: perl -Ilib examples/sms_example.pl\n";
} else {
    print "❌ SSL issues detected. Install missing modules:\n";
    print "   cpanm Mozilla::CA LWP::Protocol::https IO::Socket::SSL\n";
}

print "\nEnvironment variables:\n";
print "  PERL_LWP_SSL_CA_FILE: " . ($ENV{PERL_LWP_SSL_CA_FILE} || "not set") . "\n";
print "  PERL_LWP_SSL_VERIFY_HOSTNAME: " . ($ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} || "not set") . "\n";
