FROM perl:5.36-slim

RUN apt-get update && apt-get install -y libssl-dev make gcc && rm -rf /var/lib/apt/lists/*

RUN cpanm --notest \
    LWP::UserAgent \
    LWP::Protocol::https \
    JSON \
    HTTP::Request::Common \
    File::Basename \
    MIME::Base64 \
    Mozilla::CA \
    IO::Socket::SSL \
    Digest::SHA \
    Digest::MD5

COPY lib/ /sdk/lib/
COPY integration/ /sdk/integration/

ENV PERL5LIB=/sdk/lib
ENV CCAI_SUPPRESS_WARNINGS=1

CMD ["perl", "/sdk/integration/test.pl"]
