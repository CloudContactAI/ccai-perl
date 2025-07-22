#!/usr/bin/env perl

use strict;
use warnings;
use 5.016;

use lib '../lib';
use CCAI;

# Create a CCAI client
my $ccai = CCAI->new({
    client_id => '2682',
    api_key   => 'eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJpbmZvQGFsbGNvZGUuY29tIiwiaXNzIjoiY2xvdWRjb250YWN0IiwibmJmIjoxNzE5NDQwMjM2LCJpYXQiOjE3MTk0NDAyMzYsInJvbGUiOiJVU0VSIiwiY2xpZW50SWQiOjI2ODIsImlkIjoyNzY0LCJ0eXBlIjoiQVBJX0tFWSIsImtleV9yYW5kb21faWQiOiI1MGRiOTUzZC1hMjUxLTRmZjMtODI5Yi01NjIyOGRhOGE1YTAifQ.PKVjXYHdjBMum9cTgLzFeY2KIb9b2tjawJ0WXalsb8Bckw1RuxeiYKS1bw5Cc36_Rfmivze0T7r-Zy0PVj2omDLq65io0zkBzIEJRNGDn3gx_AqmBrJ3yGnz9s0WTMr2-F1TFPUByzbj1eSOASIKeI7DGufTA5LDrRclVkz32Oo'
});

# Example 1: Send a single email
send_single_email($ccai);

# Example 2: Send an email campaign to multiple recipients
send_email_campaign($ccai);

# Example 3: Schedule an email campaign for future delivery
schedule_email_campaign($ccai);

# Example 1: Send a single email
sub send_single_email {
    my ($ccai) = @_;
    
    print "Sending a single email...\n";
    
    my $response = $ccai->email->send_single(
        "John",                                    # First name
        "Doe",                                     # Last name
        "john@example.com",                        # Email address (replace with a real email for testing)
        "Welcome to Our Service",                  # Subject
        "<p>Hello \${first_name},</p><p>Thank you for signing up for our service!</p><p>Best regards,<br>The Team</p>",  # HTML message content
        "noreply\@yourcompany.com",                # Sender email (replace with your sender email)
        "support\@yourcompany.com",                # Reply-to email (replace with your reply-to email)
        "Your Company",                            # Sender name
        "Welcome Email",                           # Campaign title
        {
            on_progress => sub { print "Status: $_[0]\n" }  # Progress callback
        }
    );
    
    if ($response->{success}) {
        print "Email sent successfully: ID=$response->{data}->{id}, Status=$response->{data}->{status}\n";
    } else {
        print "Failed to send email: $response->{error}\n";
    }
    
    print "\n";
}

# Example 2: Send an email campaign to multiple recipients
sub send_email_campaign {
    my ($ccai) = @_;
    
    print "Sending an email campaign to multiple recipients...\n";
    
    my $campaign = {
        subject => "Monthly Newsletter",
        title => "July 2025 Newsletter",
        message => <<'HTML',
<h1>Monthly Newsletter - July 2025</h1>
<p>Hello ${first_name},</p>
<p>Here are our updates for this month:</p>
<ul>
    <li>New feature: Email campaigns</li>
    <li>Improved performance</li>
    <li>Bug fixes</li>
</ul>
<p>Thank you for being a valued customer!</p>
<p>Best regards,<br>The Team</p>
HTML
        sender_email => "newsletter\@yourcompany.com",  # Replace with your sender email
        reply_email => "support\@yourcompany.com",      # Replace with your reply-to email
        sender_name => "Your Company Newsletter",
        accounts => [
            {
                first_name => "John",
                last_name => "Doe",
                email => "john@example.com"  # Replace with a real email for testing
            },
            {
                first_name => "Jane",
                last_name => "Smith",
                email => "jane@example.com"  # Replace with a real email for testing
            }
        ],
        campaign_type => "EMAIL",
        add_to_list => "noList",
        contact_input => "accounts",
        from_type => "single",
        senders => []
    };
    
    my $response = $ccai->email->send_campaign(
        $campaign,
        {
            on_progress => sub { print "Status: $_[0]\n" }  # Progress callback
        }
    );
    
    if ($response->{success}) {
        print "Email campaign sent successfully: ID=$response->{data}->{id}, Status=$response->{data}->{status}\n";
        print "Messages sent: $response->{data}->{messagesSent}\n" if $response->{data}->{messagesSent};
    } else {
        print "Failed to send email campaign: $response->{error}\n";
    }
    
    print "\n";
}

# Example 3: Schedule an email campaign for future delivery
sub schedule_email_campaign {
    my ($ccai) = @_;
    
    print "Scheduling an email campaign for future delivery...\n";
    
    # Schedule for tomorrow at 10:00 AM
    my $tomorrow = time() + 86400;  # 24 hours from now
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = gmtime($tomorrow);
    $year += 1900;
    $mon += 1;
    my $scheduled_timestamp = sprintf("%04d-%02d-%02dT10:00:00Z", $year, $mon, $mday);
    
    my $campaign = {
        subject => "Upcoming Event Reminder",
        title => "Event Reminder Campaign",
        message => <<'HTML',
<h1>Reminder: Upcoming Event</h1>
<p>Hello ${first_name},</p>
<p>This is a reminder about our upcoming event tomorrow at 2:00 PM.</p>
<p>We look forward to seeing you there!</p>
<p>Best regards,<br>The Events Team</p>
HTML
        sender_email => "events\@yourcompany.com",  # Replace with your sender email
        reply_email => "events\@yourcompany.com",   # Replace with your reply-to email
        sender_name => "Your Company Events",
        accounts => [
            {
                first_name => "John",
                last_name => "Doe",
                email => "john@example.com"  # Replace with a real email for testing
            }
        ],
        campaign_type => "EMAIL",
        scheduled_timestamp => $scheduled_timestamp,
        scheduled_timezone => "America/New_York",
        add_to_list => "noList",
        contact_input => "accounts",
        from_type => "single",
        senders => []
    };
    
    my $response = $ccai->email->send_campaign($campaign);
    
    if ($response->{success}) {
        print "Email campaign scheduled successfully: ID=$response->{data}->{id}, Status=$response->{data}->{status}\n";
        print "Scheduled for: $scheduled_timestamp (America/New_York)\n";
    } else {
        print "Failed to schedule email campaign: $response->{error}\n";
    }
    
    print "\n";
}
