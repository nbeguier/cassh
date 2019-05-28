FROM python:3.6

WORKDIR /opt/cassh
ENTRYPOINT ["/opt/cassh/server/docker-entrypoint"]

RUN apt-get update \
    && apt-get install -yqq \
        openssh-client \
        openssl \
        libldap2-dev \
        libsasl2-dev \
    && rm -rf /var/lib/apt/lists/*


COPY requirements.txt ./

RUN pip install --no-cache-dir -r requirements.txt

COPY . server/
