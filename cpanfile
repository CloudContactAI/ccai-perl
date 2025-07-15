requires 'LWP::UserAgent';
requires 'JSON';
requires 'HTTP::Request::Common';
requires 'File::Basename';
requires 'MIME::Base64';
requires 'File::Slurp';

on 'test' => sub {
    requires 'Test::More';
    requires 'Test::Exception';
};
