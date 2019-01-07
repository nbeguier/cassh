# CASSH

SSH keys management at scale !

[![Build Status](https://travis-ci.org/leboncoin/cassh.svg?branch=master)](https://travis-ci.org/leboncoin/cassh)


A client / server app to ease management of PKI based SSH keys.

Developped for @leboncoin

https://medium.com/leboncoin-engineering-blog/cassh-ssh-key-signing-tool-39fd3b8e4de7


<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [TL;DR](#tldr)
  - [Requirements](#requirements)
  - [Usage](#usage)
    - [User](#user)
    - [Admin](#admin)
- [Install](#install)
  - [Server](#server)
    - [Install](#install-1)
    - [Config](#config)
    - [Init the Database](#init-the-database)
    - [Run](#run)
  - [WebUI](#webui)
  - [Client](#client)
    - [Install](#install-2)
    - [Config](#config-1)
- [CASSH-server features](#cassh-server-features)
  - [Active SSL](#active-ssl)
  - [Active LDAP](#active-ldap)
- [Dev setup](#dev-setup)
  - [Requirements](#requirements-1)
  - [Developpement](#developpement)
  - [Automated tasks](#automated-tasks)
  - [Tests](#tests)
  - [CI](#ci)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->



## TL;DR

### Requirements

Server:
* `Python`
* `Postgres` as backend
* `openssh-client` (`ssh-keygen`)

CLI:
* `Python`


OR `docker`


### Usage

#### User

Add new key to cassh-server :
```
cassh add
```

Sign pub key :
```
cassh sign [--display-only] [--force]
```

Get public key status :
```
cassh status
```

Get ca public key :
```
cassh ca
```

Get ca krl :
```
cassh krl
```

#### Admin

Active Client **username** key :
```
cassh admin <username> active
```

Revoke Client **username** key :
```
cassh admin <username> revoke
```

Delete Client **username** key :
```
cassh admin <username> delete
```

Status Client **username** key :
```
cassh admin <username> status
```

Set Client **username** key :
```
cassh admin <username> set --set='expiry=+7d'
cassh admin <username> set --set='principals=username,root'
```

#### Configuration file

```ini
[user]
# name : this is the username you will use to log on every server
name = user
# key_path: This key path won\'t be used to log in, a copy will be made for the certificate.
# We assume that `${key_path}` exists and `${key_path}.pub` as well.
# WARNING: Never delete these keys
key_path = ~/.ssh/id_rsa
# key_signed_path: Every signed key via cassh will be put in this path.
# At every sign, `${key_signed_path}` and `${key_signed_path}.pub` will be created
key_signed_path = ~/.ssh/id_rsa-cert
# url : URL of cassh server-side backend.
url = https://cassh.net
# [OPTIONNAL] timeout : requests timeout parameter in second. (timeout=2)
# timeout = 2
# [OPTIONNAL] verify : verifies SSL certificates for HTTPS requests. (verify=True)
# verify = True

[ldap]
# realname : this is the LDAP/AD login user
realname = ursula.ser@domain.fr
```


## Install

### Server

#### Install

```bash
# Python Pip
sudo apt-get install \
    python-pip \
    python-dev \
    libsasl2-dev \
    libldap2-dev \
    libssl-dev \
    libpq-dev

pip install -r src/server/requirements.txt
```
OR

```bash
# Debian packages
sudo apt-get install \
    python-psycopg2 \
    python-webpy \
    python-ldap \
    python-configparser \
    python-requests \
    python-openssl
```

OR

```
docker pull leboncoin/cassh-server:VERSION
```


#### Config

```bash
# Generate CA ssh key and revocation key file
mkdir test-keys
ssh-keygen -C CA -t rsa -b 4096 -o -a 100 -N "" -f /etc/cassh-server/ca/id_rsa_ca # without passphrase
ssh-keygen -k -f /etc/cassh-server/krl/revoked-keys
```


```ini
# cassh.conf
[main]
ca = /etc/cassh-server/ca/id_rsa_ca
krl = /etc/cassh-server/krl/revoked-keys
port = 8080
# Optionnal : admin_db_failover is used to bypass db when it fails.
# admin_db_failover = False

[postgres]
host = cassh.domain.fr
dbname = casshdb
user = cassh
password = xxxxxxxx

# Highly recommended
[ldap]
host = ldap.domain.fr
bind_dn = OU=User,DC=domain,DC=fr
admin_cn = CN=Admin,OU=Group,DC=domain,DC=fr
# Key in user result to get his LDAP realname
filterstr = userPrincipalName

# Optionnal
[ssl]
private_key = /etc/cassh-server/ssl/cert.key
public_key = /etc/cassh-server/ssl/cert.pem
```


#### Init the Database

* You need a database and a user's credentials 
* Init the database with this sql statement: [SQL Model](src/server/sql/model.sql)
* Update the `cassh-server` config with the user's credentials


#### Run

```bash
python src/server/server.py --config "/etc/cassh-server/cassh.conf"
```

or

```bash
docker run --rm \
  --volume=/etc/cassh-server/cassh.conf:/opt/cassh/server/conf/cassh.conf \
  --volume=${CASSH_KEYS_DIR}:${CASSH_KEYS_DIR} \
  --publish "8080:8080" \
  leboncoin/cassh-server
```



### WebUI

A webui based on `flask` is also available for client not familiar with CLI.
It must run on the same OS than the `cassh-server`.

```bash
pip3 insall -r src/server/web/requirements.txt

python3 src/server/web/cassh_web.py
```



### Client

#### Install

Python 3

```bash
sudo apt-get install python3-pip
pip3 install -r src/client/requirements.txt

alias cassh="${PWD}/src/client/cassh"
```

Python 2

```bash
sudo apt-get install python-pip
pip install -r src/client/requirements.txt

alias cassh="${PWD}/src/client/cassh"
```

Docker

```bash
./contrib/cassh_docker.sh
```

Put in your Shell rc file `alias cassh="PATH_TO/contrib/cassh_docker.sh"`


#### Config

Sample available at [./src/client/cassh-client.conf](./src/client/cassh-client.conf)




## CASSH-server features

### Active SSL
```ini
[ssl]
private_key = __CASSH_PATH__/ssl/server.key
public_key = __CASSH_PATH__/ssl/server.pem
```

### Active LDAP
```ini
[ldap]
host = ldap.domain.fr
bind_dn = OU=User,DC=domain,DC=fr
admin_cn = CN=Admin,OU=Group,DC=domain,DC=fr
# Key in user result to get his LDAP realname
filterstr = userPrincipalName
```




## Dev setup

### Requirements

Needed:
* `docker` : https://docs.docker.com/engine/installation/
* `docker-compose`: https://docs.docker.com/compose/installation/
* `invoke`: http://www.pyinvoke.org/

If installed and run locally:
* `bats`: https://github.com/sstephenson/bats
* `curl`, `jq` & `openssh-client` with your distro packages manager


### Developpement

Start the server and its dependencies:

```
$ cd tests/
$ docker-compose up cassh-server
```


In an other shell, submit `cassh` CLI commands:

```
$ cd tests/
$ docker-compose run cassh-cli

Starting tests_db_1 ... done
Starting tests_cassh-server_1 ... done
usage: cassh [-h] [--version] {admin,add,sign,status,ca,krl} ...

positional arguments:
  {admin,add,sign,status,ca,krl}
                        commands
    admin               Administrator command : active - revoke - delete -
                        status - set keys
    add                 Add a key to remote ssh ca server.
    sign                Sign its key by remote ssh ca server.
    status              Display key current status on remote ssh ca server.
    ca                  Display CA public key.
    krl                 Display CA KRL.

optional arguments:
  -h, --help            show this help message and exit
  --version             show program's version number and exit
```


### Automated tasks

Some redondent tasks are automated using `invoke`.
They are defined in the [`tasks/`](./tasks/) directory.

```bash
$ invoke -l

Available tasks:

  build.all              Build cassh & cassh-server docker images
  build.cassh            Build cassh CLI
  build.cassh-server     Build cassh-server
  release.all            Push cassh & cassh-server docker images to Docker hub
  release.cassh          Push cassh CLI docker image to Docker hub
  release.cassh-server   Push cassh-server docker image to Docker hub
  test.e2e               End to End tests of CASSH-server and CASSH cli
  test.lint-client       pylint cassh
  test.lint-server       pylint cassh-server
```


### Tests

```bash
$ invoke test.e2e
```


### CI

* CI jobs are configured on [Travis-ci.org](https://travis-ci.org/leboncoin/cassh).
* You can configure and see what is run by reading [.travis.yml](.travis.yml).
* On successful tests, docker images are published on docker hub 
  - https://hub.docker.com/r/leboncoin/cassh/
  - https://hub.docker.com/r/leboncoin/cassh-server/

