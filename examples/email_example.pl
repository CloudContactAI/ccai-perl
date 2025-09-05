#!/usr/bin/env perl

use strict;
use warnings;
use 5.016;

use lib '../lib';
use CCAI;

# Create a CCAI client for test environment
my $ccai = CCAI->new({
    client_id => 'YOUR_CLIENT_ID',
    api_key   => 'YOUR_API_KEY'
    base_url  => 'https://core-test-cloudcontactai.allcode.com/api',
    email_url => 'https://email-campaigns-test-cloudcontactai.allcode.com',
    auth_url  => 'https://auth-test-cloudcontactai.allcode.com'
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
        "andreas\@allcode.com",                   # Email address
        "Welcome to Our Service",                  # Subject
        "<p>Hello \${firstName},</p><p>Thank you for signing up for our service!</p><p>Best regards,<br>The Team</p>",  # HTML message content
        "noreply\@allcode.com",                   # Sender email
        "support\@allcode.com",                   # Reply-to email
        "CCAI Test",                               # Sender name
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
<p>Hello ${firstName},</p>
<p>Here are our updates for this month:</p>
<ul>
    <li>New feature: Email campaigns</li>
    <li>Improved performance</li>
    <li>Bug fixes</li>
</ul>
<p>Thank you for being a valued customer!</p>
<p>Best regards,<br>The Team</p>
HTML
        sender_email => "newsletter\@allcode.com",
        reply_email => "support\@allcode.com",
        sender_name => "CCAI Newsletter",
        accounts => [
            {
                firstName => "John",
                lastName => "Doe",
                email => "john\@example.com"
            },
            {
                firstName => "Jane",
                lastName => "Smith",
                email => "jane\@example.com"
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
<p>Hello ${firstName},</p>
<p>This is a reminder about our upcoming event tomorrow at 2:00 PM.</p>
<p>We look forward to seeing you there!</p>
<p>Best regards,<br>The Events Team</p>
HTML
        sender_email => "events\@allcode.com",
        reply_email => "events\@allcode.com",
        sender_name => "CCAI Events",
        accounts => [
            {
                firstName => "John",
                lastName => "Doe",
                email => "john\@example.com"
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
