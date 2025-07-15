use 5.016;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'CCAI',
    AUTHOR           => q{CloudContactAI LLC <support@cloudcontactai.com>},
    VERSION_FROM     => 'lib/CCAI.pm',
    ABSTRACT         => 'Perl client for the Cloud Contact AI API',
    LICENSE          => 'mit',
    PL_FILES         => {},
    MIN_PERL_VERSION => '5.016',
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => '0',
    },
    BUILD_REQUIRES => {
        'Test::More' => '0',
        'Test::Exception' => '0',
    },
    PREREQ_PM => {
        'LWP::UserAgent'        => '0',
        'JSON'                  => '0',
        'HTTP::Request::Common' => '0',
        'File::Basename'        => '0',
        'MIME::Base64'          => '0',
        'File::Slurp'           => '0',
        'Carp'                  => '0',
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'CCAI-*' },
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources => {
            repository => {
                type => 'git',
                url  => 'https://github.com/cloudcontactai/ccai-perl.git',
                web  => 'https://github.com/cloudcontactai/ccai-perl',
            },
            bugtracker => {
                web => 'https://github.com/cloudcontactai/ccai-perl/issues',
            },
            homepage => 'https://cloudcontactai.com',
        },
        keywords => ['sms', 'api', 'client', 'cloud', 'contact', 'ai', 'cloudcontactai'],
    },
);
