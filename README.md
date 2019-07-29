# CASSH

[![Build Status](https://travis-ci.org/nbeguier/cassh.svg?branch=master)](https://travis-ci.org/nbeguier/cassh) [![Python 3.2|3.6](https://img.shields.io/badge/python-3.2|3.6-green.svg)](https://www.python.org/) [![License](https://img.shields.io/badge/Licence-Apache%202.0-blue.svg)](https://github.com/nbeguier/cassh/blob/master/LICENSE)

OpenSSH features reach their limit when it comes to industrialization. We don’t want an administrator to sign every user’s public key by hand every day, so we need a service for that. That is exactly the purpose of CASSH: **signing keys**!
Developped for @leboncoin

https://medium.com/leboncoin-engineering-blog/cassh-ssh-key-signing-tool-39fd3b8e4de7

  - [CLI version : **1.6.2** *(23/05/2019)*](src/client/CHANGELOG.md) [![Known Vulnerabilities](https://snyk.io//test/github/nbeguier/cassh/badge.svg?targetFile=src/client/requirements.txt)](https://snyk.io//test/github/nbeguier/cassh?targetFile=src/client/requirements.txt)
  - [WebUI version : **1.1.0** *(29/07/2019)*](src/server/web/CHANGELOG.md) [![Known Vulnerabilities](https://snyk.io//test/github/nbeguier/cassh/badge.svg?targetFile=src/server/web/requirements.txt)](https://snyk.io//test/github/nbeguier/cassh?targetFile=src/server/web/requirements.txt)
  - [Server version : **1.9.2** *(29/07/2019)*](src/server/CHANGELOG.md) [![Known Vulnerabilities](https://snyk.io//test/github/nbeguier/cassh/badge.svg?targetFile=src/server/requirements.txt)](https://snyk.io//test/github/nbeguier/cassh?targetFile=src/server/requirements.txt)

## Usage

### Client CLI

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

### Admin CLI

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

### Configuration file

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

## Prerequisites

### Server

```bash
# Install cassh python 3 service dependencies
sudo apt-get install openssh-client openssl libldap2-dev libsasl2-dev build-essential python3-dev
sudo apt-get install python3-pip
pip3 install -r src/server/requirements.txt

# Generate CA ssh key and revocation key file
mkdir test-keys
ssh-keygen -C CA -t rsa -b 4096 -o -a 100 -N "" -f test-keys/id_rsa_ca # without passphrase
ssh-keygen -k -f test-keys/revoked-keys
```

Configuration file example :
```ini
[main]
ca = /etc/cassh/ca/id_rsa_ca
krl = /etc/cassh/krl/revoked-keys
port = 8080
# Optionnal : admin_db_failover is used to bypass db when it fails.
# admin_db_failover = False
# Optionnal : cluster is used to list the cluster member
# cluster = http://192.168.0.1:8080,http://192.168.0.2:8080
# Optionnal : clustersecret is the shared secret used by cluster member
# clustersecret = clustersecretpassword
# Optionnal : debug is used to enable the debug. Should not be used into production
# debug = True

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

### Server : Database

* You need a database and a user's credentials 
* Init the database with this sql statement: [SQL Model](src/server/sql/model.sql)
* Update the `cassh-server` config with the user's credentials

### Server : Client web user interface
```bash
pip3 insall -r src/server/web/requirements.txt
python3 src/server/web/cassh_web.py
```

### Client

```bash
# Python 3
sudo apt-get install python3-pip
pip3 install -r src/client/requirements.txt

# Python 2
sudo apt-get install python-pip
pip install -r src/client/requirements.txt
```

## Features on CASSH server

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


## Quick test

### Server side

Install docker : https://docs.docker.com/engine/installation/


#### Prerequisites

```bash
# Make a 'sudo' only if your user doesn't have docker rights, add your user into docker group
pip install -r tests/requirements.txt

# Set the postgres host in the cassh-server configuration
cp tests/cassh_dummy.conf tests/cassh.conf
# Generate temporary certificates
mkdir test-keys
ssh-keygen -C CA -t rsa -b 4096 -o -a 100 -N "" -f test-keys/id_rsa_ca # without passphrase
ssh-keygen -k -f test-keys/revoked-keys

# /!\ Wait for the container demo-postgres to be started
sed -i "s/host = localhost/host = $(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' demo-postgres)/g" tests/cassh.conf

# Duplicate the cassh.conf
cp tests/cassh.conf tests/cassh_2.conf
# Generate another krl
ssh-keygen -k -f test-keys/revoked-keys-2
sed -i "s/revoked-keys/revoked-keys-2/g" tests/cassh_2.conf
```

#### One instance


```bash
# Launch this on another terminal
bash tests/launch_demo_server.sh --server_code_path ${PWD} --debug
$ /opt/cassh/src/server/server.py --config /opt/cassh/tests/cassh.conf

# When 'http://0.0.0.0:8080/' appears, start this script
bash tests/test.sh
```

#### Multiple instances

The same as previsouly, but launch this to specify a second cassh-server instance

```bash
# Launch this on another terminal
bash tests/launch_demo_server.sh --server_code_path ${PWD} --debug --port 8081
$ /opt/cassh/src/server/server.py --config /opt/cassh/tests/cassh_2.conf
```


### Client side

Generate key pair then sign it !

```bash
git clone https://github.com/nbeguier/cassh.git /opt/cassh
cd /opt/cassh

# Generate key pair
mkdir test-keys
ssh-keygen -t rsa -b 4096 -o -a 100 -f test-keys/id_rsa

rm -f ~/.cassh
cat << EOF > ~/.cassh
[user]
name = user
key_path = ${PWD}/test-keys/id_rsa
key_signed_path = ${PWD}/test-keys/id_rsa-cert
url = http://localhost:8080

[ldap]
realname = user@test.fr
EOF

# List keys
python cassh status

# Add it into server
python cassh add

# ADMIN: Active key
python cassh admin user active

# Sign it !
python cassh sign [--display-only]
```
