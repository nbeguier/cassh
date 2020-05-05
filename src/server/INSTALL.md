# INSTALL - Cassh Server

## From scratch

### Prerequisites

```bash
# Install cassh python 3 service dependencies
sudo apt install openssh-client openssl libldap2-dev libsasl2-dev build-essential python3-dev
sudo apt install python3-pip
pip install -U pip
pip install -r requirements.txt

# Generate CA ssh key and revocation key file
mkdir test-keys
ssh-keygen -C CA -t rsa -b 4096 -o -a 100 -N "" -f test-keys/id_rsa_ca # without passphrase
ssh-keygen -k -f test-keys/revoked-keys
```

### Server : Database

* You need a database and a user's credentials 
* Init the database with this sql statement: [SQL Model](sql/model.sql)
* Update the `cassh-server` config with the user's credentials

## Optionnal features

### Active SSL
```ini
[ssl]
private_key = __CASSH_PATH__/ssl/server.key
public_key = __CASSH_PATH__/ssl/server.pem
```

### Active LDAP
```ini
[ldap]
host = ldap.example.org
bind_dn = dc=example,dc=org
username = cn=cassh,dc=example,dc=org
password = mypassword
admin_cn = cn=admin,dc=example,dc=org
# LDAP key to match realname
filter_realname_key = userPrincipalName
# LDAP key to match admin_cn
filter_memberof_key = memberOf
# Optionnal:
# username_prefix = cn=
# username_suffix = ,dc=example,dc=org
```

## Docker

TODO
But you can use environment variables to override default configuration.
```
export CASSH_SERVER_ADMIN_DB_FAILOVER=admin_db_failover
export CASSH_SERVER_CA=ca
export CASSH_SERVER_CLUSTER=cluster
export CASSH_SERVER_CLUSTER_SECRET=clustersecret
export CASSH_SERVER_DB_HOST=db_host
export CASSH_SERVER_DB_NAME=db_name
export CASSH_SERVER_DB_PASSWORD=db_password
export CASSH_SERVER_DB_USER=db_user
export CASSH_SERVER_DEBUG=debug
export CASSH_SERVER_KRL=krl
export CASSH_SERVER_LDAP_ADMIN_CN=ldap_admin_cn
export CASSH_SERVER_LDAP_BIND_DN=ldap_bind_dn
export CASSH_SERVER_LDAP_FILTER_MEMBEROF_KEY=ldap_filter_memberof_key
export CASSH_SERVER_LDAP_FILTER_REALNAME_KEY=ldap_filter_realname_key
export CASSH_SERVER_LDAP_HOST=ldap_host
export CASSH_SERVER_LDAP_MAPPING_PATH=ldap_mapping_path
export CASSH_SERVER_LDAP_PASSWORD=ldap_password
export CASSH_SERVER_LDAP_USERNAME=ldap_username
export CASSH_SERVER_LDAP_USERNAME_PREFIX=ldap_username_prefix
export CASSH_SERVER_LDAP_USERNAME_SUFFIX=ldap_username_suffix
export CASSH_SERVER_PORT=port
export CASSH_SERVER_SSL_PRIVATE_KEY=ssl_private_key
export CASSH_SERVER_SSL_PUBLIC_KEY=ssl_public_key
```
