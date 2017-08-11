# CASSH

Easy SSH for admin ONLY !
Developped for @leboncoin

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

### Client

```bash
# Python 3
sudo apt-get install python3-pip
pip3 install -r requirements.txt

# Python 2
sudo apt-get install python-pip
pip install -r requirements.txt
```


Then, initialize a postgresql db. If you don't have one, install demo database.

### Optional: Demo database
```bash
sudo apt-get install docker.io

# Make a 'sudo' only if your user doesn't have docker rights, add your user into docker group
bash demo/server_init.sh

# Finally, start server
sed -i "s#__CASSH_PATH__#${PWD}#g" demo/cassh_dummy.conf
python server/server.py --config demo/cassh_dummy.conf
```

## Usage

### Client CLI

Add new key to cassh-server :
```
$ python cassh add
```

Sign pub key :
```
$ python cassh sign
```

Get public key status :
```
$ python cassh status
```

Get ca public key :
```
$ python cassh ca
```

Get ca krl :
```
python cassh krl
```

### Admin CLI

Active Client **username** key :
```
python cassh admin <username> active
```

Revoke Client **username** key :
```
python cassh admin <username> revoke
```

Delete Client **username** key :
```
python cassh admin <username> delete
```

Status Client **username** key :
```
python cassh admin <username> status
```


## Features

### Active SSL
```ini
[main]
ca = __CASSH_PATH__/test-keys/id_rsa_ca
krl = __CASSH_PATH__/test-keys/revoked-keys

[ssl]
private_key = __CASSH_PATH__/ssl/server.key
public_key = __CASSH_PATH__/ssl/server.pem
```

### Active LDAP
```ini
[main]
ca = __CASSH_PATH__/test-keys/id_rsa_ca
krl = __CASSH_PATH__/test-keys/revoked-keys

[ldap]
host = ad.domain.fr
bind_dn = CN=%%s,OU=Utilisateurs,DC=Domain,DC=fr
admin_cn = CN=Admin,OU=Groupes,DC=Domain,DC=fr
```


## Quick test

Generate key pair then sign it !

```bash
git clone https://github.com/Petlefeu/cassh.git /opt/cassh
cd /opt/cassh

# Generate key pair
mkdir test-keys
ssh-keygen -t rsa -b 4096 -o -a 100 -f test-keys/id_rsa

rm -f ~/.cassh
cat << EOF > ~/.cassh
[user]
name = user
key_path = ${PWD}/test-keys/id_rsa
key_signed_path = ${PWD}/test-keys/id_rsa_signed
url = http://localhost:8080
EOF

# List keys
python cassh status

# Add it into server
python cassh add

# ADMIN: Active key
python cassh admin user active

# Sign it !
python cassh sign
```
The output is the signing key.
