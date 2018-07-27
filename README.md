# CASSH

SSH keys management @scale !

[![Build Status](https://travis-ci.org/leboncoin/cassh.svg?branch=master)](https://travis-ci.org/leboncoin/cassh)


A client / server app to ease management of PKI based SSH keys.

Developped for @leboncoin

https://nicolasbeguier.shost.ca/cassh.html





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
    - [WebUI](#webui)
  - [Client](#client)
    - [Install](#install-2)
    - [Config](#config-1)
- [CASSH-server features](#cassh-server-features)
  - [Active SSL](#active-ssl)
  - [Active LDAP](#active-ldap)
- [Dev setup](#dev-setup)
  - [Requirements](#requirements-1)
  - [Tests](#tests)
  - [Developpement](#developpement)

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
$ cassh add
```

Sign pub key :
```
$ cassh sign [--display-only] [--uid=UID] [--force]
```

Get public key status :
```
$ cassh status
```

Get ca public key :
```
$ cassh ca
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
docker pull leboncoin/cassh-server
```


#### Config

```bash
# Generate CA ssh key and revocation key file
mkdir test-keys
ssh-keygen -C CA -t rsa -b 4096 -o -a 100 -N "" -f test-keys/id_rsa_ca # without passphrase
ssh-keygen -k -f test-keys/revoked-keys
```


```bash
# cassh.conf
[main]
ca = /etc/cassh/ca/id_rsa_ca
krl = /etc/cassh/krl/revoked-keys
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
private_key = /etc/cassh/ssl/cert.key
public_key = /etc/cassh/ssl/cert.pem
```


#### Init the Database

* You need a database and a user's credentials 
* Init the database with this sql statement: [SQL Model](src/server/sql/model.sql)
* Update the `cassh-server` config with the user's credentials


#### WebUI

A webui based on `flask` is also available for client not familiar with CLI:

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

alias cassh="${PWD}/contrib/cassh_docker.sh"
```


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

* `docker` : https://docs.docker.com/engine/installation/
* `docker-compose`: https://docs.docker.com/compose/installation/
* `bats`: https://github.com/sstephenson/bats
* `curl`, `jq` & `openssh-client` with your distro packages manager


### Tests

```bash
tests/tests.sh
```


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


