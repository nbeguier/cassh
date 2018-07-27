FROM debian:latest

# Container options (For layer optim)
WORKDIR /opt/cassh
ENTRYPOINT ["/opt/cassh/server/docker-entrypoint"]

RUN apt-get update \
    && apt-get install -yqq \
        openssh-client \
        openssl \
        python-psycopg2 \
        python-webpy \
        python-ldap \
        python-configparser \
        python-requests \
        python-openssl \
    && rm -rf /var/lib/apt/lists/*

COPY . server/
