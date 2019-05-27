FROM debian:latest

# Container options (For layer optim)
WORKDIR /opt/cassh
ENTRYPOINT ["/opt/cassh/server/docker-entrypoint"]

RUN apt-get update \
    && apt-get install -yqq \
        openssh-client \
        openssl \
        libldap2-dev \
        libsasl2-dev \
        python-pip \
    && rm -rf /var/lib/apt/lists/*

COPY . server/

RUN pip install -r server/requirements.txt
