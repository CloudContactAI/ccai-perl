#!/bin/bash

# CCAI Perl SMS Example Runner
# This script ensures the example runs from any terminal

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Change to the ccai-perl directory
cd "$SCRIPT_DIR"

# Check if we're in the right directory
if [ ! -f "lib/CCAI.pm" ]; then
    echo "Error: CCAI.pm not found. Make sure you're running this from the ccai-perl directory."
    exit 1
fi

# Run the SMS example with proper library path
echo "Running SMS example from: $(pwd)"
echo "Using Perl: $(which perl)"
echo "----------------------------------------"

perl -Ilib examples/sms_example.pl
