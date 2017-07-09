# LBCSSH

Easy SSH for admin ONLY !
Developped for @leboncoin

## Prerequisites

```bash
# Demo PG database
sudo apt-get install docker.io

# Server side
sudo apt-get install python-psycopg2 python-webpy python-ldap

mkdir test-keys
ssh-keygen -C CA -t rsa -b 4096 -o -a 100 -N "" -f test-keys/id_rsa_ca # without passphrase


# Client side
# Python 3
sudo apt-get install python3-pip

# Python 2
sudo apt-get install python-pip
```

Then, initialize a postgresql db. If you already have one, reconfigure server.py
```bash
# Make a 'sudo' only if your user doesn't have docker rights, add your user into docker group
bash demo/server_init.sh
```

Finally, start server
```bash
bash demo/server_start.sh test-keys/id_rsa_ca
```

## Client CLI

```bash
# Add new key to lbcssh-server
python lbcssh add

# Sign pub key
python lbcssh sign

# Get public key status
python lbcssh status

# Get ca public key
python lbcssh ca

# Get ca krl
python lbcssh krl
```

## Admin CLI

```bash
# Active Client 'username' key
python lbcssh admin <username> active

# Revoke Client 'username' key
python lbcssh admin <username> revoke

# Delete Client 'username' key
python lbcssh admin <username> delete
```


## Features

### Active SSL
```bash
python server/server.py --ca test-keys/id_rsa_ca --ssl --ssl-private-key ssl/server.key --ssl-certificate ssl/server.pem
```

### Active LDAP
```bash
python server/server.py --ca test-keys/id_rsa_ca --enable-ldap --ldap-host ldap.domain.fr --ldap-binddn 'CN=%s,OU=Utilisateurs,DC=fr'
```


## Quick test

Generate key pair then sign it !

```bash
# Generate key pair
mkdir test-keys
ssh-keygen -t rsa -b 4096 -o -a 100 -f test-keys/id_rsa

rm -f ~/.lbcssh
cat << EOF > ~/.lbcssh
[user]
name = user
pubkey_path = ${PWD}/test-keys/id_rsa.pub
url = http://localhost:8080
EOF

# List keys (just in case... it should be '[]')
curl http://localhost:8080/client

# Add it into server
curl -X PUT -d @test-keys/id_rsa.pub http://localhost:8080/client/toto

# ADMIN: Active key
curl http://localhost:8080/admin/toto?revoke=false

# Sign it !
curl -X POST -d @test-keys/id_rsa.pub http://localhost:8080/client/toto
```
The output is the signing key.
