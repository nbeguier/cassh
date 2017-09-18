#!/usr/bin/env python

"""
Sign a user's SSH public key.
"""
from __future__ import print_function
from argparse import ArgumentParser
from datetime import datetime
from json import dumps
from os import remove
from tempfile import NamedTemporaryFile
from time import time

# Third party library imports
from configparser import ConfigParser, NoOptionError
from ldap import open as ldap_open
from psycopg2 import connect, OperationalError, ProgrammingError
from web import application, data, httpserver, input as web_input
from web.wsgiserver import CherryPyWSGIServer

# Own library
from ssh_utils import Authority, get_fingerprint

# DEBUG
# from pdb import set_trace as st

URLS = (
    '/admin/([a-z]+)', 'Admin',
    '/ca', 'Ca',
    '/client', 'Client_All',
    '/client/([a-z]+)', 'Client',
    '/krl', 'Krl',
    '/test_auth', 'Test_Auth',
)

STATES = {
    0: 'ACTIVE',
    1: 'REVOKED',
    2: 'PENDING',
}

PARSER = ArgumentParser()
PARSER.add_argument('-c', '--config', action='store', help='Configuration file')
PARSER.add_argument('-v', '--verbose', action='store_true', default=False, help='Add verbosity')
ARGS = PARSER.parse_args()

if not ARGS.config:
    PARSER.error('--config argument is required !')

CONFIG = ConfigParser()
CONFIG.read(ARGS.config)
SERVER_OPTS = {}
SERVER_OPTS['ca'] = CONFIG.get('main', 'ca')
SERVER_OPTS['krl'] = CONFIG.get('main', 'krl')
SERVER_OPTS['port'] = CONFIG.get('main', 'port')
SERVER_OPTS['ldap'] = False
SERVER_OPTS['ssl'] = False

if CONFIG.has_section('postgres'):
    try:
        SERVER_OPTS['db_host'] = CONFIG.get('postgres', 'host')
        SERVER_OPTS['db_name'] = CONFIG.get('postgres', 'dbname')
        SERVER_OPTS['db_user'] = CONFIG.get('postgres', 'user')
        SERVER_OPTS['db_password'] = CONFIG.get('postgres', 'password')
    except NoOptionError:
        if ARGS.verbose:
            print('Option reading error (postgres).')
        exit(1)

if CONFIG.has_section('ldap'):
    try:
        SERVER_OPTS['ldap'] = True
        SERVER_OPTS['ldap_host'] = CONFIG.get('ldap', 'host')
        SERVER_OPTS['ldap_bind_dn'] = CONFIG.get('ldap', 'bind_dn')
        SERVER_OPTS['ldap_admin_cn'] = CONFIG.get('ldap', 'admin_cn')
    except NoOptionError:
        if ARGS.verbose:
            print('Option reading error (ldap).')
        exit(1)

if CONFIG.has_section('ssl'):
    try:
        SERVER_OPTS['ssl'] = True
        SERVER_OPTS['ssl_private_key'] = CONFIG.get('ssl', 'private_key')
        SERVER_OPTS['ssl_public_key'] = CONFIG.get('ssl', 'public_key')
    except NoOptionError:
        if ARGS.verbose:
            print('Option reading error (ssl).')
        exit(1)

def sql_to_json(result):
    """
    This function prettify a sql result into json
    """
    d_result = {}
    if result is not None:
        d_result['username'] = result[0]
        d_result['realname'] = result[1]
        d_result['status'] = STATES[result[2]]
        d_result['expiration'] = datetime.fromtimestamp(result[3]).strftime('%Y-%m-%d %H:%M:%S')
        d_result['ssh_key_hash'] = result[4]
    return dumps(d_result, indent=4, sort_keys=True)

def pg_connection(
        dbname=SERVER_OPTS['db_name'],
        user=SERVER_OPTS['db_user'],
        host=SERVER_OPTS['db_host'],
        password=SERVER_OPTS['db_password']):
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

def list_keys(username=None, realname=None):
    """
    Return all keys.
    """
    pg_conn, message = pg_connection()
    if pg_conn is None:
        return message
    cur = pg_conn.cursor()

    if realname is not None:
        cur.execute("""SELECT * FROM USERS WHERE REALNAME='%s'""" % realname)
        result = cur.fetchone()
    elif username is not None:
        cur.execute("""SELECT * FROM USERS WHERE NAME='%s'""" % username)
        result = cur.fetchone()
    else:
        cur.execute("""SELECT * FROM USERS""")
        result = cur.fetchall()
    cur.close()
    pg_conn.close()
    return sql_to_json(result)

def ldap_authentification(admin=False):
    """
    Return True if user is well authentified
    """
    if SERVER_OPTS['ldap']:
        try:
            real_name = web_input()['realname']
        except KeyError:
            real_name = None
            return False
        password = web_input()['password']
        ldap_conn = ldap_open(SERVER_OPTS['ldap_host'])
        try:
            ldap_conn.bind_s(SERVER_OPTS['ldap_bind_dn'] % real_name, password)
        except:
            return False
        if admin and SERVER_OPTS['ldap_admin_cn'] not in\
            ldap_conn.search_s(SERVER_OPTS['ldap_bind_dn'] % real_name, 2)[0][1]['memberOf']:
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
            ca_ssh = Authority(SERVER_OPTS['ca'], SERVER_OPTS['krl'])
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


class Client_All():
    """
    Class which retrun all client keys.
    """
    def GET(self):
        """
        Get client key status.
        """
        try:
            realname = web_input()['realname']
        except KeyError:
            return 'Error : No realname given'

        return list_keys(realname=realname)

    def POST(self):
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

        # Search if key already exists
        cur.execute("""SELECT * FROM USERS WHERE SSH_KEY='%s' AND REALNAME='%s'""" \
            % (pubkey, get_realname()))
        user = cur.fetchone()
        if user is None:
            cur.close()
            pg_conn.close()
            remove(tmp_pubkey.name)
            return 'Error : User or Key absent, add your key again.'

        username = user[0]

        if user[2] > 0:
            cur.close()
            pg_conn.close()
            remove(tmp_pubkey.name)
            return "Status: %s" % STATES[user[2]]

        # Load SSH CA
        ca_ssh = Authority(SERVER_OPTS['ca'], SERVER_OPTS['krl'])

        # Sign the key
        try:
            cert_contents = ca_ssh.sign_public_user_key(\
                tmp_pubkey.name, username, '+1d', username)
            cur.execute("""UPDATE USERS SET STATE=0, EXPIRATION=%s WHERE NAME='%s'"""\
                % (time() + 24*60*60, username))
        except:
            cert_contents = 'Error : signing key'
        remove(tmp_pubkey.name)
        pg_conn.commit()
        cur.close()
        pg_conn.close()
        return cert_contents

class Ca():
    """
    Class CA.
    """
    def GET(self):
        """
        Return ca.
        """
        return open(SERVER_OPTS['ca'] + '.pub', 'rb')

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
            return "Status: %s" % STATES[user[2]]

        # Load SSH CA
        ca_ssh = Authority(SERVER_OPTS['ca'], SERVER_OPTS['krl'])

        # Sign the key
        try:
            cert_contents = ca_ssh.sign_public_user_key(\
                tmp_pubkey.name, username, '+1d', username)
            cur.execute("""UPDATE USERS SET STATE=0, EXPIRATION=%s WHERE NAME='%s'"""\
                % (time() + 24*60*60, username))
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


class Krl():
    """
    Class KRL.
    """
    def GET(self):
        """
        Return krl.
        """
        return open(SERVER_OPTS['krl'], 'rb')


class Test_Auth():
    """
    Test authentication
    """
    def GET(self):
        """
        Test authentication
        """
        if not ldap_authentification(admin=True):
            return 'Error : Authentication'
        return 'OK'


class MyApplication(application):
    """
    Can change port or other stuff
    """
    def run(self, port=int(SERVER_OPTS['port']), *middleware):
        func = self.wsgifunc(*middleware)
        return httpserver.runsimple(func, ('0.0.0.0', port))

if __name__ == "__main__":
    if SERVER_OPTS['ssl']:
        CherryPyWSGIServer.ssl_certificate = SERVER_OPTS['ssl_public_key']
        CherryPyWSGIServer.ssl_private_key = SERVER_OPTS['ssl_private_key']
    if ARGS.verbose:
        print('SSL: %s' % SERVER_OPTS['ssl'])
        print('LDAP: %s' % SERVER_OPTS['ldap'])
    APP = MyApplication(URLS, globals())
    APP.run()
