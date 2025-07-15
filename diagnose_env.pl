#!/usr/bin/env perl

use strict;
use warnings;

print "Perl Environment Diagnostic\n";
print "=" x 40 . "\n";

print "1. Current Directory: " . `pwd`;
print "2. Perl Executable: " . `which perl`;
print "3. Perl Version: ";
system("perl -v | head -2 | tail -1");

print "\n4. Perl Library Paths (\@INC):\n";
for my $path (@INC) {
    print "   $path\n";
}

print "\n5. Environment Variables:\n";
print "   PERL5LIB: " . ($ENV{PERL5LIB} || "not set") . "\n";
print "   PERL_LWP_SSL_CA_FILE: " . ($ENV{PERL_LWP_SSL_CA_FILE} || "not set") . "\n";
print "   PATH: " . substr($ENV{PATH}, 0, 100) . "...\n";

print "\n6. Testing Required Modules:\n";
my @modules = qw(LWP::UserAgent JSON HTTP::Request::Common Mozilla::CA LWP::Protocol::https);

for my $module (@modules) {
    print "   $module: ";
    eval "require $module";
    if ($@) {
        print "✗ MISSING\n";
    } else {
        print "✓ OK\n";
    }
}

print "\n7. Testing CCAI Module:\n";
print "   CCAI: ";
eval {
    require lib;
    lib->import('lib');
    require CCAI;
};
if ($@) {
    print "✗ FAILED: $@\n";
} else {
    print "✓ OK\n";
}

print "\n8. SSL Configuration Test:\n";
eval {
    require Mozilla::CA;
    my $ca_file = Mozilla::CA::SSL_ca_file();
    print "   CA File: $ca_file\n";
    print "   File Exists: " . (-f $ca_file ? "YES" : "NO") . "\n";
};
if ($@) {
    print "   SSL Config: ✗ FAILED: $@\n";
}
