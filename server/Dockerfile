FROM debian:latest

# Container options (For layer optim)
WORKDIR /opt/cassh
ENTRYPOINT ["python", "/opt/cassh/server/server.py"]
CMD ["--config", "/opt/cassh/server/conf/cassh.conf"]

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
