requires 'LWP::UserAgent';
requires 'JSON';
requires 'HTTP::Request::Common';
requires 'File::Basename';
requires 'MIME::Base64';
requires 'File::Slurp';
requires 'Mozilla::CA';
requires 'LWP::Protocol::https';
requires 'IO::Socket::SSL';

on 'test' => sub {
    requires 'Test::More';
    requires 'Test::Exception';
};
