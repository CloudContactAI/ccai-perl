package CCAI::EnvLoader;

use strict;
use warnings;
use 5.016;

use Carp qw(croak);
use File::Spec;

=head1 NAME

CCAI::EnvLoader - Simple .env file loader for CCAI examples

=head1 SYNOPSIS

    use CCAI::EnvLoader;
    
    # Load .env file from current directory
    CCAI::EnvLoader->load();
    
    # Load .env file from specific path
    CCAI::EnvLoader->load('/path/to/.env');
    
    # Access environment variables
    my $client_id = $ENV{CCAI_CLIENT_ID};
    my $api_key = $ENV{CCAI_API_KEY};

=head1 DESCRIPTION

CCAI::EnvLoader provides a simple way to load environment variables from a .env file
for use in CCAI examples and applications.

=head1 METHODS

=head2 load($env_file)

Load environment variables from a .env file.

    CCAI::EnvLoader->load();           # Load from ./.env
    CCAI::EnvLoader->load('.env');     # Load from ./.env
    CCAI::EnvLoader->load('/path/to/.env');  # Load from specific path

Parameters:
- env_file: Optional path to .env file (defaults to '.env' in current directory)

The .env file format supports:
- KEY=value
- KEY="value with spaces"
- KEY='single quoted value'
- # Comments (lines starting with #)
- Empty lines (ignored)

=cut

sub load {
    my ($class, $env_file) = @_;
    
    # Default to .env in current directory
    $env_file //= '.env';
    
    # Check if file exists
    unless (-f $env_file) {
        # Don't croak, just warn - .env files are optional
        warn "Warning: .env file not found at '$env_file'\n";
        return;
    }
    
    # Open and read the .env file
    open my $fh, '<', $env_file or do {
        warn "Warning: Cannot read .env file '$env_file': $!\n";
        return;
    };
    
    my $line_number = 0;
    while (my $line = <$fh>) {
        $line_number++;
        chomp $line;
        
        # Skip empty lines and comments
        next if $line =~ /^\s*$/ || $line =~ /^\s*#/;
        
        # Parse KEY=value format
        if ($line =~ /^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$/) {
            my ($key, $value) = ($1, $2);
            
            # Handle quoted values
            if ($value =~ /^"(.*)"$/) {
                # Double quoted - handle escape sequences
                $value = $1;
                $value =~ s/\\n/\n/g;
                $value =~ s/\\t/\t/g;
                $value =~ s/\\r/\r/g;
                $value =~ s/\\\\/\\/g;
                $value =~ s/\\"/"/g;
            } elsif ($value =~ /^'(.*)'$/) {
                # Single quoted - literal value
                $value = $1;
            } else {
                # Unquoted - trim whitespace
                $value =~ s/^\s+|\s+$//g;
            }
            
            # Set environment variable (don't override existing ones)
            $ENV{$key} = $value unless exists $ENV{$key};
            
        } else {
            warn "Warning: Invalid .env format at line $line_number: $line\n";
        }
    }
    
    close $fh;
    
    return 1;
}

=head2 get_ccai_credentials()

Get CCAI credentials from environment variables with helpful error messages.

    my ($client_id, $api_key) = CCAI::EnvLoader->get_ccai_credentials();

Returns:
- client_id: Value of CCAI_CLIENT_ID environment variable
- api_key: Value of CCAI_API_KEY environment variable

Dies with helpful error message if credentials are not found.

=cut

sub get_ccai_credentials {
    my ($class) = @_;
    
    my $client_id = $ENV{CCAI_CLIENT_ID};
    my $api_key = $ENV{CCAI_API_KEY};
    
    unless ($client_id) {
        croak "CCAI_CLIENT_ID environment variable is required.\n" .
              "Please set it in your .env file or environment:\n" .
              "  CCAI_CLIENT_ID=your-client-id-here\n";
    }
    
    unless ($api_key) {
        croak "CCAI_API_KEY environment variable is required.\n" .
              "Please set it in your .env file or environment:\n" .
              "  CCAI_API_KEY=your-api-key-here\n";
    }
    
    return ($client_id, $api_key);
}

1;

__END__

=head1 AUTHOR

CloudContactAI LLC

=head1 LICENSE

MIT License

Copyright (c) 2025 CloudContactAI LLC

=cut
