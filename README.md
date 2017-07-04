# admin-ssh
Easy SSH for admin ONLY !

## Prerequisites

```bash
sudo apt-get install python-psycopg2 python-webpy docker.io

mkdir test-keys

ssh-keygen -C CA -t rsa -b 4096 -o -a 100 -N "" -f test-keys/id_rsa_ca # without passphrase
```

Then, initialize db
```bash
# Make a 'sudo' only if your user doesn't have docker rights, add your user into docker group
bash demo/server_init.sh
```

Finally, start server
```bash
bash demo/server_start.sh test-keys/id_rsa_ca
```

## Quick test

Generate key pair then sign it !

```bash
# Generate key pair
ssh-keygen -t rsa -b 4096 -o -a 100 -f test-keys/id_rsa

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
