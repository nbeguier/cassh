# CASSH

Easy SSH for admin ONLY !
Developped for @leboncoin

https://nicolasbeguier.shost.ca/cassh.html

## Prerequisites

### Server

```bash
# Install cassh python 2 service dependencies
sudo apt-get install libsasl2-dev python-dev libldap2-dev libssl-dev libpq-dev
sudo apt-get install python-pip
pip install -r server/requirements_python2.txt
# or
sudo apt-get install python-psycopg2 python-webpy python-ldap python-configparser python-requests python-openssl

# Generate CA ssh key and revocation key file
mkdir test-keys
ssh-keygen -C CA -t rsa -b 4096 -o -a 100 -N "" -f test-keys/id_rsa_ca # without passphrase
ssh-keygen -k -f test-keys/revoked-keys
```

Configuration file example :
```
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

### Server : Database

You need to create a database.

### Server : Client web user interface
```bash
pip3 insall -r requirements.txt
python3 server/web/cassh_web.py
```

### Client

```bash
# Python 3
sudo apt-get install python3-pip
pip3 install -r requirements.txt

# Python 2
sudo apt-get install python-pip
pip install -r requirements.txt
```


## Usage

### Client CLI

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


```bash
# Make a 'sudo' only if your user doesn't have docker rights, add your user into docker group
pip install psycopg2
bash tests/launch_demo_server.sh

# When 'http://0.0.0.0:8080/' appears, start it on another terminal
bash tests/test.sh

# Full debug
bash tests/launch_demo_server.sh --server_file ${PWD}/server/server.py --debug
$ /opt/cassh/server/server.py --config /opt/cassh/tests/cassh_dummy.conf

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
