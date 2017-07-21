#!/usr/bin/env python

"""
Sign a user's SSH public key.
"""
from __future__ import print_function
from argparse import ArgumentParser
from os import remove
from tempfile import NamedTemporaryFile
from time import time

# Third party library imports
from ldap import open as ldap_open
from psycopg2 import connect, OperationalError, ProgrammingError
from web import application, data, httpserver, input as web_input
from web.wsgiserver import CherryPyWSGIServer

# Own library
from ssh_utils import Authority, get_fingerprint

# DEBUG
# from pdb import set_trace as st

URLS = (
    '/client', 'AllClientKeys',
    '/client/([a-z]+)', 'Client',
    '/admin/([a-z]+)', 'Admin',
    '/ca', 'Ca',
    '/krl', 'Krl',
)

STATES = {
    0: 'ACTIVE',
    1: 'REVOKED',
    2: 'PENDING',
}

PARSER = ArgumentParser()
PARSER.add_argument('--ca', action='store', help='CA private key')
PARSER.add_argument('--krl', action='store', help='CA KRL')
PARSER.add_argument('--enable-ldap', action='store_true', help='Enable LDAP authentication')
PARSER.add_argument('--ldap-host', action='store', help='LDAP server hostname')
PARSER.add_argument('--ldap-binddn', action='store', help='LDAP BindDN')
PARSER.add_argument('--ldap-admin_cn', action='store',\
    help='LDAP Admin CN (Ex: CN=Admin,OU=Groupes,OU=Enterprise,DC=fr')
PARSER.add_argument('--ssl', action='store_true', help='Active SSL/TLS')
PARSER.add_argument('--ssl-certificate', action='store', help='SSL public certificate')
PARSER.add_argument('--ssl-private-key', action='store', help='SSL private key')

ARGS = PARSER.parse_args()


def pg_connection(dbname='postgres', user='postgres', host='localhost',\
    password='mysecretpassword'):
    """
    Return a connection to the db.
    """
    message = ''
    try:
        pg_conn = connect("dbname='%s' user='%s' host='%s' password='%s'"\
            % (dbname, user, host, password))
    except OperationalError:
        return None, 'Server cannot connect to database'
    try:
        pg_conn.cursor().execute("""SELECT * FROM USERS""")
    except ProgrammingError:
        return None, 'Server cannot connect to table in database'
    return pg_conn, message

def list_keys(username=None):
    """
    Return all keys.
    """
    pg_conn, message = pg_connection()
    if pg_conn is None:
        return message
    cur = pg_conn.cursor()

    # Search if key already exists
    if username is not None:
        cur.execute("""SELECT * FROM USERS WHERE NAME='%s'""" % username)
        result = cur.fetchone()
    else:
        cur.execute("""SELECT * FROM USERS""")
        result = cur.fetchall()
    cur.close()
    pg_conn.close()
    return result

def ldap_authentification(admin=False):
    """
    Return True if user is well authentified
    """
    if ARGS.enable_ldap:
        try:
            real_name = web_input()['realname']
        except KeyError:
            real_name = None
            return False
        password = web_input()['password']
        if ARGS.ldap_host is None\
            or ARGS.ldap_binddn is None\
            or ARGS.ldap_admin_cn is None:
            print('Cannot parse ldap args : Host=%s, BindDN=%s, Admin_CN=%s'\
                % (ARGS.ldap_host, ARGS.ldap_binddn, ARGS.ldap_admin_cn))
            return False
        ldap_conn = ldap_open(ARGS.ldap_host)
        try:
            ldap_conn.bind_s(ARGS.ldap_binddn % real_name, password)
        except:
            return False
        if admin and ARGS.ldap_admin_cn not in\
            ldap_conn.search_s(ARGS.ldap_binddn % real_name, 2)[0][1]['memberOf']:
            return False
    return True

def get_realname():
    """
    Return realname or None
    """
    try:
        real_name = web_input()['realname']
    except KeyError:
        real_name = None
    return real_name

class AllClientKeys():
    """
    Class which retrun all client keys.
    """
    def GET(self):
        """
        Get every client key status.
        """
        if not ldap_authentification(admin=True):
            return 'Error : Authentication'
        try:
            username = web_input()['username']
        except KeyError:
            username = None

        return list_keys(username=username)

class Client():
    """
    Client class.
    """
    def GET(self, username):
        """
        Return informations.
        """
        if not ldap_authentification():
            return 'Error : Authentication'
        return list_keys(username=username)


    def POST(self, username):
        """
        Ask to sign pub key.
        """
        if not ldap_authentification():
            return 'Error : Authentication'
        pubkey = data()
        tmp_pubkey = NamedTemporaryFile(delete=False)
        tmp_pubkey.write(pubkey)
        tmp_pubkey.close()
        pg_conn, message = pg_connection()
        if pg_conn is None:
            remove(tmp_pubkey.name)
            return message
        cur = pg_conn.cursor()

        # Check if realname is the same
        cur.execute("""SELECT * FROM USERS WHERE NAME='%s' AND REALNAME='%s'"""\
            % (username, get_realname()))
        if cur.fetchone() is None:
            return 'Error : Authentication'

        # Search if key already exists
        cur.execute("""SELECT * FROM USERS WHERE SSH_KEY='%s' AND NAME='%s'""" \
            % (pubkey, username))
        user = cur.fetchone()
        if user is None:
            cur.close()
            pg_conn.close()
            remove(tmp_pubkey.name)
            return 'Error : User or Key absent, add your key again.'

        if user[2] > 0:
            cur.close()
            pg_conn.close()
            remove(tmp_pubkey.name)
            return "Status: %s" % STATES[user[1]]

        # Load SSH CA
        ca_ssh = Authority(ARGS.ca, ARGS.krl)

        # Sign the key
        try:
            cert_contents = ca_ssh.sign_public_user_key(\
                tmp_pubkey.name, username, '+1d', username)
            cur.execute("""UPDATE USERS SET STATE=0, EXPIRATION=%s WHERE NAME='%s'"""\
                % (time(), username))
        except:
            cert_contents = 'Error : signing key'
        remove(tmp_pubkey.name)
        pg_conn.commit()
        cur.close()
        pg_conn.close()
        return cert_contents

    def PUT(self, username):
        """
        This function permit to add or update a ssh public key.
        """
        if not ldap_authentification():
            return 'Error : Authentication'
        pubkey = data()
        tmp_pubkey = NamedTemporaryFile(delete=False)
        tmp_pubkey.write(pubkey)
        tmp_pubkey.close()
        pubkey_fingerprint = get_fingerprint(tmp_pubkey.name)
        pg_conn, message = pg_connection()
        if pg_conn is None:
            remove(tmp_pubkey.name)
            return message
        cur = pg_conn.cursor()

        # Search if key already exists
        cur.execute("""SELECT * FROM USERS WHERE NAME='%s'""" % username)
        user = cur.fetchone()

        # CREATE NEW USER
        if user is None:
            cur.execute("""INSERT INTO USERS VALUES ('%s', '%s', %s, %s, '%s', '%s')""" \
                % (username, get_realname(), 2, 0, pubkey_fingerprint, pubkey))
            pg_conn.commit()
            cur.close()
            pg_conn.close()
            remove(tmp_pubkey.name)
            return 'Create user=%s. Pending request.' % username
        else:
            # Check if realname is the same
            cur.execute("""SELECT * FROM USERS WHERE NAME='%s' AND REALNAME='%s'"""\
                % (username, get_realname()))
            if cur.fetchone() is None:
                return 'Error : Authentication'
            # Update entry into database
            cur.execute("""UPDATE USERS SET SSH_KEY='%s', SSH_KEY_HASH='%s', STATE=2, EXPIRATION=0 \
                WHERE NAME = '%s'""" % (pubkey, pubkey_fingerprint, username))
            pg_conn.commit()
            cur.close()
            pg_conn.close()
            remove(tmp_pubkey.name)
            return 'Update user=%s. Pending request.' % username

class Admin():
    """
    Class admin to action or revoke keys.
    """
    def GET(self, username):
        """
        Revoke or Active keys.
        """
        if not ldap_authentification(admin=True):
            return 'Error : Authentication'
        do_revoke = web_input()['revoke'] == 'true'
        pg_conn, message = pg_connection()
        if pg_conn is None:
            return message
        cur = pg_conn.cursor()

        # Search if key already exists
        cur.execute("""SELECT * FROM USERS WHERE NAME='%s'""" % username)
        user = cur.fetchone()
        # If user dont exist
        if user is None:
            cur.close()
            pg_conn.close()
            message = "User '%s' does not exists." % username
        elif do_revoke:
            cur.execute("""UPDATE USERS SET STATE=1 WHERE NAME = '%s'""" % username)
            pg_conn.commit()
            message = 'Revoke user=%s.' % username
            # Load SSH CA and revoke key
            ca_ssh = Authority(ARGS.ca, ARGS.krl)
            cur.execute("""SELECT SSH_KEY FROM USERS WHERE NAME = '%s'""" % username)
            pubkey = cur.fetchone()[0]
            tmp_pubkey = NamedTemporaryFile(delete=False)
            tmp_pubkey.write(pubkey)
            tmp_pubkey.close()
            ca_ssh.update_krl(tmp_pubkey.name)
            cur.close()
            pg_conn.close()
            remove(tmp_pubkey.name)
        # If user is in PENDING state
        elif user[2] == 2:
            cur.execute("""UPDATE USERS SET STATE=0 WHERE NAME = '%s'""" % username)
            pg_conn.commit()
            cur.close()
            pg_conn.close()
            message = 'Active user=%s. SSH Key active but need to be signed.' % username
        # If user is in REVOKE state
        elif user[2] == 1:
            cur.execute("""UPDATE USERS SET STATE=0 WHERE NAME = '%s'""" % username)
            pg_conn.commit()
            cur.close()
            pg_conn.close()
            message = 'Active user=%s. SSH Key active but need to be signed.' % username
        else:
            cur.close()
            pg_conn.close()
            message = 'user=%s already active. Nothing done.' % username
        return message

    def DELETE(self, username):
        """
        Delete keys (but DOESN'T REVOKE)
        """
        if not ldap_authentification(admin=True):
            return 'Error : Authentication'
        pg_conn, message = pg_connection()
        if pg_conn is None:
            return message
        cur = pg_conn.cursor()

        # Search if key already exists
        cur.execute("""DELETE FROM USERS WHERE NAME='%s'""" % username, )
        pg_conn.commit()
        cur.close()
        pg_conn.close()
        return 'OK'

class Ca():
    """
    Class CA.
    """
    def GET(self):
        """
        Return ca.
        """
        return open(ARGS.ca + '.pub', 'rb')

class Krl():
    """
    Class KRL.
    """
    def GET(self):
        """
        Return krl.
        """
        return open(ARGS.krl, 'rb')

class MyApplication(application):
    """
    Can change port or other stuff
    """
    def run(self, port=8080, *middleware):
        func = self.wsgifunc(*middleware)
        return httpserver.runsimple(func, ('0.0.0.0', port))

if __name__ == "__main__":
    if not ARGS.ca:
        PARSER.error('--ca argument is required !')
    if not ARGS.krl:
        PARSER.error('--krl argument is required !')

    if ARGS.ssl and not (ARGS.ssl_certificate and ARGS.ssl_private_key):
        PARSER.error('You have to give --ssl-private-key and --ssl-certificate arguments')

    if ARGS.ssl:
        CherryPyWSGIServer.ssl_certificate = ARGS.ssl_certificate
        CherryPyWSGIServer.ssl_private_key = ARGS.ssl_private_key
    APP = MyApplication(URLS, globals())
    APP.run()
