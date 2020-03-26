FROM python:3.8

WORKDIR /opt/cassh

RUN apt-get update \
    && apt-get install -yqq \
        openssh-client \
        openssl \
        libldap2-dev \
        libsasl2-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt ./

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD [ "python", "./server.py" ]
