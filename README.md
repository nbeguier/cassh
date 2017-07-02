# admin-ssh
Easy SSH for admin ONLY !

## Prerequisites

```bash
sudo apt-get install python-psycopg2 python-webpy docker.io

mkdir test-keys
cd test-keys

ssh-keygen -C CA -f ca # without passphrase
```

Then, initialize db
```bash
# sudo is only if your user doesn't have docker rights, add it into docker group
sudo bash demo/server_init.sh
```

Finally, start server
```bash
bash demo/server_start.sh test-keys/ca
```

## Quick test

Generate key pair then sign it !

```bash
# Generate key pair
ssh-keygen -t ecdsa -f test-keys/id_rsa

# List keys (just in case... it should be '[]')
curl http://localhost:8080/client

# Add it into server
curl -X PUT -d @test-keys/id_rsa.pub http://localhost:8080/client/toto

# ADMIN: Active key
curl http://localhost:8080/admin/toto?sign=true

# Sign it !
curl -X POST -d @test-keys/id_rsa.pub http://localhost:8080/client/toto
```
The output is the signing key.
