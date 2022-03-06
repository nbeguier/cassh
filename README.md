# CASSH

[![Build Status](https://travis-ci.com/nbeguier/cassh.svg?branch=master)](https://travis-ci.com/nbeguier/cassh) [![Python 3.5|3.9](https://img.shields.io/badge/python-3.5|3.9-green.svg)](https://www.python.org/) [![License](https://img.shields.io/github/license/nbeguier/cassh?color=blue)](https://github.com/nbeguier/cassh/blob/master/LICENSE)

OpenSSH features reach their limit when it comes to industrialization. We don’t want an administrator to sign every user’s public key by hand every day, so we need a service for that. That is exactly the purpose of CASSH: **signing keys**!
Developped for @leboncoin

https://medium.com/leboncoin-engineering-blog/cassh-ssh-key-signing-tool-39fd3b8e4de7

  - [CLI version : **1.8.0** *(10/05/2021)*](src/client/CHANGELOG.md) ![leboncoin/cassh](https://img.shields.io/docker/pulls/leboncoin/cassh) + ![nbeguier/cassh-client](https://img.shields.io/docker/pulls/nbeguier/cassh-client) [![docker-build](https://img.shields.io/docker/cloud/automated/nbeguier/cassh-client)](https://hub.docker.com/r/nbeguier/cassh-client)
  - [WebUI version : **1.3.0** *(10/05/2021)*](src/server/web/CHANGELOG.md) ![nbeguier/cassh-web](https://img.shields.io/docker/pulls/nbeguier/cassh-web) [![docker-build](https://img.shields.io/docker/cloud/automated/nbeguier/cassh-web)](https://hub.docker.com/r/nbeguier/cassh-web)
  - [Server version : **2.3.1** *(06/03/2022)*](src/server/CHANGELOG.md) ![leboncoin/cassh-server](https://img.shields.io/docker/pulls/leboncoin/cassh-server) + ![nbeguier/cassh-server](https://img.shields.io/docker/pulls/nbeguier/cassh-server) [![docker-build](https://img.shields.io/docker/cloud/automated/nbeguier/cassh-server)](https://hub.docker.com/r/nbeguier/cassh-server)

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

```
usage: cassh admin [-h] [-s SET] [--add-principals ADD_PRINCIPALS]
                   [--remove-principals REMOVE_PRINCIPALS]
                   [--purge-principals]
                   [--update-principals UPDATE_PRINCIPALS]
                   [--principals-filter PRINCIPALS_FILTER]
                   username action

positional arguments:
  username              Username of client's key, if username is 'all' status
                        return all users
  action                Choice between : active, delete, revoke, set, search,
                        status keys

optional arguments:
  -h, --help            show this help message and exit
  -s SET, --set SET     CAUTION: Set value of a user.
  --add-principals ADD_PRINCIPALS
                        Add a list of principals to a user, should be
                        separated by comma without spaces.
  --remove-principals REMOVE_PRINCIPALS
                        Remove a list of principals to a user, should be
                        separated by comma without spaces.
  --purge-principals    Purge all principals to a user.
  --update-principals UPDATE_PRINCIPALS
                        Update all principals to a user by the given
                        principals, should be separated by comma without
                        spaces.
  --principals-filter PRINCIPALS_FILTER
                        Look for users by the given principals filter, should
                        be separated by comma without spaces.
```

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
# Set expiry to 7 days
cassh admin <username> set --set='expiry=7d'

# Add principals to existing ones
cassh admin <username> set --add-principals foo,bar

# Remove principals from existing ones
cassh admin <username> set --remove-principals foo,bar

# Update principals and erease existsing ones
cassh admin <username> set --update-principals foo,bar

# Purge principals
cassh admin <username> set --purge-principals
```

Search **Principals** among clients :
```
cassh admin all search --principals-filter foo,bar
```

## Install

### Server

[INSTALL.md](src/server/INSTALL.md)

### Client

[INSTALL.md](src/client/INSTALL.md)

### Cassh WebUI

[INSTALL.md](src/server/web/INSTALL.md)


## Quick test

### Server side

Install docker : https://docs.docker.com/engine/installation/

#### Prerequisites

```bash
# install utilities needed by tests/test.sh
sudo apt install pwgen jq

# Make a 'sudo' only if your user doesn't have docker rights, add your user into docker group
pip install -r tests/requirements.txt

cp tests/cassh/cassh.conf.sample tests/cassh/cassh.conf
cp tests/cassh/ldap_mapping.json.sample tests/cassh/ldap_mapping.json

# Edit cassh.conf file to configure the hosts

# Generate temporary certificates
mkdir test-keys
ssh-keygen -C CA -t rsa -b 4096 -o -a 100 -N "" -f test-keys/id_rsa_ca # without passphrase
ssh-keygen -k -f test-keys/revoked-keys

############################################
# BEGIN THE ONE OR MULTIPLE INSTANCES STEP #
############################################

# Duplicate the cassh.conf
cp tests/cassh/cassh.conf tests/cassh/cassh_2.conf
# Generate another krl
ssh-keygen -k -f test-keys/revoked-keys-2
sed -i "s/revoked-keys/revoked-keys-2/g" tests/cassh/cassh_2.conf
```

#### One instance


```bash
# Launch this on another terminal
bash tests/launch_demo_server.sh --server_code_path ${PWD} --debug
$ /opt/cassh/src/server/server.py --config /opt/cassh/tests/cassh/cassh.conf

# When 'http://0.0.0.0:8080/' appears, start this script
bash tests/test.sh
```

#### Multiple instances

The same as previsouly, but launch this to specify a second cassh-server instance

```bash
# Launch this on another terminal
bash tests/launch_demo_server.sh --server_code_path ${PWD} --debug --port 8081
$ /opt/cassh/src/server/server.py --config /opt/cassh/tests/cassh/cassh_2.conf
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

# License
Licensed under the [Apache License](https://github.com/nbeguier/cassh/blob/master/LICENSE), Version 2.0 (the "License").

# Copyright
Copyright 2017-2022 Nicolas BEGUIER; ([nbeguier](https://beguier.eu/nicolas/) - nicolas_beguier[at]hotmail[dot]com)
