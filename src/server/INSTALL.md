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
# ldap procotol can be: ldap, ldaps or starttls
protocol = ldap
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
