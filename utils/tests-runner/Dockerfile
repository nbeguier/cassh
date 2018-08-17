FROM debian:latest

RUN echo "* Install OS dependencies" \
    && apt-get update \
    && apt-get install -yqq \
        openssh-client \
        curl \
        jq \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN echo "* Install tests dependencies" \
    && apt-get update \
    && apt-get install -yqq \
        git \
    && git clone https://github.com/sstephenson/bats.git /tmp/bats \
    && /tmp/bats/install.sh /usr/local/ \
    && apt-get autoremove -yqq git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

SHELL ["/bin/bash", "-c"]