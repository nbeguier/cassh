#!/usr/bin/env python
"""
Sign a user's SSH public key.

Copyright 2017 Nicolas BEGUIER
Licensed under the Apache License, Version 2.0
Written by Nicolas BEGUIER (nicolas_beguier@hotmail.com)

"""

from argparse import ArgumentParser
from json import dumps
from os import remove
from re import compile as re_compile, IGNORECASE
from tempfile import NamedTemporaryFile
from urllib.parse import unquote_plus

# Third party library imports
from configparser import ConfigParser, NoOptionError
from ldap import initialize, SCOPE_SUBTREE
from web import application, config, data, httpserver
from cheroot.server import HTTPServer
from cheroot.ssl.builtin import BuiltinSSLAdapter

# Own library
from ssh_utils import get_fingerprint
from tools import get_principals, get_pubkey, random_string, response_render, timestamp, unquote_custom, Tools

# DEBUG
# from pdb import set_trace as st

STATES = {
    0: 'ACTIVE',
    1: 'REVOKED',
    2: 'PENDING',
}

PATTERN_EXPIRY = re_compile('^\\+([0-9]+)+[dh]$')
PATTERN_PRINCIPALS = re_compile("^([a-zA-Z-]+)$")
PATTERN_REALNAME = re_compile(
    r"(^[-!#$%&'*+/=?^_`{}|~0-9A-Z]+(\.[-!#$%&'*+/=?^_`{}|~0-9A-Z]+)*"
    r'|^"([\001-\010\013\014\016-\037!#-\[\]-\177]|\\[\001-011\013\014\016-\177])*"'
    r')@(?:[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?\.)+[A-Z]{2,6}\.?$', IGNORECASE)
PATTERN_USERNAME = re_compile("^([a-z]+)$")

URLS = (
    '/admin/([a-z]+)', 'Admin',
    '/admin/([a-z]+)/principals', 'Principals',
    '/admin/all/principals/search', 'PrincipalsSearch',
    '/ca', 'Ca',
    '/client', 'Client',
    '/client/status', 'ClientStatus',
    '/cluster/status', 'ClusterStatus',
    '/health', 'Health',
    '/krl', 'Krl',
    '/ping', 'Ping',
    '/test_auth', 'TestAuth',
)

VERSION = '1.12.0'

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

try:
    SERVER_OPTS['admin_db_failover'] = CONFIG.get('main', 'admin_db_failover')
except NoOptionError:
    SERVER_OPTS['admin_db_failover'] = False
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
        SERVER_OPTS['filterstr'] = CONFIG.get('ldap', 'filterstr')
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

# Cluster mode is used for revocation
try:
    SERVER_OPTS['cluster'] = CONFIG.get('main', 'cluster').split(',')
except NoOptionError:
    # Standalone mode
    PROTO = 'http'
    if SERVER_OPTS['ssl']:
        PROTO = 'https'
    SERVER_OPTS['cluster'] = ['%s://localhost:%s' % (PROTO, SERVER_OPTS['port'])]

try:
    SERVER_OPTS['clustersecret'] = CONFIG.get('main', 'clustersecret')
except NoOptionError:
    # Standalone mode
    SERVER_OPTS['clustersecret'] = random_string(32)

try:
    SERVER_OPTS['debug'] = bool(CONFIG.get('main', 'debug') != 'False')
except NoOptionError:
    SERVER_OPTS['debug'] = False

TOOLS = Tools(SERVER_OPTS, STATES, VERSION)

def data2map():
    """
    Returns a map from data POST
    """
    data_map = {}
    data_str = data().decode('utf-8')
    if data_str == '':
        return data_map
    for key in data_str.split('&'):
        data_map[key.split('=')[0]] = '='.join(key.split('=')[1:])
    return data_map

def ldap_authentification(admin=False):
    """
    Return True if user is well authentified
        realname=xxxxx@domain.fr
        password=xxxxx
    """
    if SERVER_OPTS['ldap']:
        credentials = data2map()
        if 'realname' in credentials:
            realname = unquote_plus(credentials['realname'])
        else:
            return False, 'Error: No realname option given.'
        if 'password' in credentials:
            password = unquote_plus(credentials['password'])
        else:
            return False, 'Error: No password option given.'
        if password == '':
            return False, 'Error: password is empty.'
        ldap_conn = initialize("ldap://"+SERVER_OPTS['ldap_host'])
        try:
            ldap_conn.bind_s(realname, password)
        except Exception as e:
            return False, 'Error: %s' % e
        if admin:
            memberof_admin_list = ldap_conn.search_s(
                SERVER_OPTS['ldap_bind_dn'],
                SCOPE_SUBTREE,
                filterstr='(&(%s=%s)(memberOf=%s))' % (
                    SERVER_OPTS['filterstr'],
                    realname,
                    SERVER_OPTS['ldap_admin_cn']))
            if not memberof_admin_list:
                return False, 'Error: user %s is not an admin.' % realname
    return True, 'OK'

class Admin():
    """
    Class admin to action or revoke keys.
    """
    def POST(self, username):
        """
        Revoke or Active keys.
        /admin/<username>
            revoke=true/false => Revoke user
            status=true/false => Display status
        """
        # LDAP authentication
        is_admin_auth, message = ldap_authentification(admin=True)
        if not is_admin_auth:
            return response_render(message, http_code='401 Unauthorized')

        payload = data2map()

        if 'revoke' in payload:
            do_revoke = payload['revoke'].lower() == 'true'
        else:
            do_revoke = False
        if 'status' in payload:
            do_status = payload['status'].lower() == 'true'
        else:
            do_status = False

        pg_conn, message = TOOLS.pg_connection()
        if pg_conn is None:
            return response_render(message, http_code='503 Service Unavailable')
        cur = pg_conn.cursor()

        if username == 'all' and do_status:
            return response_render(
                TOOLS.list_keys(),
                content_type='application/json')

        # Search if key already exists
        cur.execute('SELECT * FROM USERS WHERE NAME=(%s)', (username,))
        user = cur.fetchone()
        # If user dont exist
        if user is None:
            cur.close()
            pg_conn.close()
            message = 'User does not exists.'
        elif do_revoke:
            cur.execute('UPDATE USERS SET STATE=1 WHERE NAME=(%s)', (username,))
            pg_conn.commit()
            pubkey = get_pubkey(username, pg_conn)
            cur.execute('INSERT INTO REVOCATION VALUES \
                ((%s), (%s), (%s))', \
                (pubkey, timestamp(), username))
            pg_conn.commit()
            message = 'Revoke user=%s.' % username
            cur.close()
            pg_conn.close()
        # Display status
        elif do_status:
            return response_render(
                TOOLS.list_keys(username=username),
                content_type='application/json')
        # If user is in PENDING state
        elif user[2] == 2:
            cur.execute('UPDATE USERS SET STATE=0 WHERE NAME=(%s)', (username,))
            pg_conn.commit()
            cur.close()
            pg_conn.close()
            message = 'Active user=%s. SSH Key active but need to be signed.' % username
        # If user is in REVOKE state
        elif user[2] == 1:
            cur.execute('UPDATE USERS SET STATE=0 WHERE NAME=(%s)', (username,))
            pg_conn.commit()
            cur.close()
            pg_conn.close()
            message = 'Active user=%s. SSH Key active but need to be signed.' % username
        else:
            cur.close()
            pg_conn.close()
            message = 'user=%s already active. Nothing done.' % username
        return response_render(message)

    def PATCH(self, username):
        """
        Set the first founded value.
        /admin/<username>
            key=value => Set the key value. Keys are in status output.
        """
        # LDAP authentication
        is_admin_auth, message = ldap_authentification(admin=True)
        if not is_admin_auth:
            return response_render(message, http_code='401 Unauthorized')

        pg_conn, message = TOOLS.pg_connection()
        if pg_conn is None:
            return response_render(message, http_code='503 Service Unavailable')
        cur = pg_conn.cursor()

        payload = data2map()

        for key, value in payload.items():
            if key == 'expiry':
                if PATTERN_EXPIRY.match(value) is None:
                    return response_render(
                        "Error: expiry doesn't match pattern {}".format(PATTERN_EXPIRY.pattern),
                        http_code='400 Bad Request')
                cur.execute('UPDATE USERS SET EXPIRY=(%s) WHERE NAME=(%s)', (value, username))
                pg_conn.commit()
                cur.close()
                pg_conn.close()
                return response_render(
                    'OK: %s=%s for %s' % (key, value, username))
            # Deprecated endpoint for principals
            elif key == 'principals':
                value = unquote_plus(value)
                for principal in value.split(','):
                    if PATTERN_PRINCIPALS.match(principal) is None:
                        return response_render(
                            'WARNING: This endpoint is deprecated, upgrade your client cassh to 1.7.0\n'+
                            "Error: principal doesn't match pattern {}".format(PATTERN_PRINCIPALS.pattern),
                            http_code='400 Bad Request')
                cur.execute('UPDATE USERS SET PRINCIPALS=(%s) WHERE NAME=(%s)', (value, username))
                pg_conn.commit()
                cur.close()
                pg_conn.close()
                return response_render(
                    'WARNING: This endpoint is deprecated, upgrade your client cassh to 1.7.0\n'+
                    'OK: %s=%s for %s' % (key, value, username))

        return response_render('WARNING: No key found...')

    def DELETE(self, username):
        """
        Delete keys (but DOESN'T REVOKE)
        /admin/<username>
        """
        # LDAP authentication
        is_admin_auth, message = ldap_authentification(admin=True)
        if not is_admin_auth:
            return response_render(message, http_code='401 Unauthorized')

        pg_conn, message = TOOLS.pg_connection()
        if pg_conn is None:
            return response_render(message, http_code='503 Service Unavailable')
        cur = pg_conn.cursor()

        # Search if key already exists
        cur.execute('DELETE FROM USERS WHERE NAME=(%s)', (username,))
        pg_conn.commit()
        cur.close()
        pg_conn.close()
        return response_render('OK')


class Ca():
    """
    Class CA.
    """
    def GET(self):
        """
        Return ca.
        """
        return response_render(
            open(SERVER_OPTS['ca'] + '.pub', 'rb'),
            content_type='application/octet-stream')

class ClientStatus():
    """
    ClientStatus main class.
    """
    def POST(self):
        """
        Get client key status.
        /client/status
        """
        # LDAP authentication
        is_auth, message = ldap_authentification()
        if not is_auth:
            return response_render(message, http_code='401 Unauthorized')

        payload = data2map()

        if 'realname' in payload:
            realname = unquote_plus(payload['realname'])
        else:
            return response_render(
                'Error: No realname option given.',
                http_code='400 Bad Request')

        return response_render(
            TOOLS.list_keys(realname=realname),
            content_type='application/json')

class Client():
    """
    Client main class.
    """
    def POST(self):
        """
        Ask to sign pub key.
        /client
            username=xxxxxx          => Unique username. Used by default to connect on server.
            realname=xxxxx@domain.fr => This LDAP/AD user.

            # Optionnal
            admin_force=true|false
        """
        # LDAP authentication
        is_auth, message = ldap_authentification()
        if not is_auth:
            return response_render(message, http_code='401 Unauthorized')

        # Check if user is an admin and want to force signature when db fail
        force_sign = False

        # LDAP ADMIN authentication
        is_admin_auth, _ = ldap_authentification(admin=True)

        payload = data2map()

        if is_admin_auth and SERVER_OPTS['admin_db_failover'] \
            and 'admin_force' in payload and payload['admin_force'].lower() == 'true':
            force_sign = True

        # Get username
        if 'username' in payload:
            username = payload['username']
        else:
            return response_render(
                'Error: No username option given. Update your CASSH >= 1.3.0',
                http_code='400 Bad Request')
        if PATTERN_USERNAME.match(username) is None or username == 'all':
            return response_render(
                "Error: username doesn't match pattern {}".format(PATTERN_USERNAME.pattern),
                http_code='400 Bad Request')

        # Get realname
        if 'realname' in payload:
            realname = unquote_plus(payload['realname'])
        else:
            return response_render(
                'Error: No realname option given.',
                http_code='400 Bad Request')

        # Get public key
        if 'pubkey' in payload:
            pubkey = unquote_custom(payload['pubkey'])
        else:
            return response_render(
                'Error: No pubkey given.',
                http_code='400 Bad Request')
        tmp_pubkey = NamedTemporaryFile(delete=False)
        tmp_pubkey.write(bytes(pubkey, 'utf-8'))
        tmp_pubkey.close()

        pubkey_fingerprint = get_fingerprint(tmp_pubkey.name)
        if pubkey_fingerprint == 'Unknown':
            remove(tmp_pubkey.name)
            return response_render(
                'Error : Public key unprocessable',
                http_code='422 Unprocessable Entity')

        pg_conn, message = TOOLS.pg_connection()
        # Admin force signature case
        if pg_conn is None and force_sign:
            cert_contents = TOOLS.sign_key(tmp_pubkey.name, username, '+12h', username)
            remove(tmp_pubkey.name)
            return response_render(cert_contents, content_type='application/octet-stream')
        # Else, if db is down it fails.
        elif pg_conn is None:
            remove(tmp_pubkey.name)
            return response_render(message, http_code='503 Service Unavailable')
        cur = pg_conn.cursor()

        # Search if key already exists
        cur.execute('SELECT * FROM USERS WHERE SSH_KEY=(%s) AND NAME=lower(%s)', (pubkey, username))
        user = cur.fetchone()
        if user is None:
            cur.close()
            pg_conn.close()
            remove(tmp_pubkey.name)
            return response_render(
                'Error : User or Key absent, add your key again.',
                http_code='400 Bad Request')

        if username != user[0] or realname != user[1]:
            cur.close()
            pg_conn.close()
            remove(tmp_pubkey.name)
            return response_render(
                'Error : (username, realname) couple mismatch.',
                http_code='401 Unauthorized')

        status = user[2]
        expiry = user[6]
        principals = get_principals(user[7], username, shell=True)

        if status > 0:
            cur.close()
            pg_conn.close()
            remove(tmp_pubkey.name)
            return response_render("Status: %s" % STATES[user[2]])

        cert_contents = TOOLS.sign_key(tmp_pubkey.name, username, expiry, principals, db_cursor=cur)

        remove(tmp_pubkey.name)
        pg_conn.commit()
        cur.close()
        pg_conn.close()
        return response_render(
            cert_contents,
            content_type='application/octet-stream')

    def PUT(self):
        """
        This function permit to add or update a ssh public key.
        /client
            username=xxxxxx          => Unique username. Used by default to connect on server.
            realname=xxxxx@domain.fr => This LDAP/AD user.
        """
        # LDAP authentication
        is_auth, message = ldap_authentification()
        if not is_auth:
            return response_render(message, http_code='401 Unauthorized')

        payload = data2map()

        if 'username' in payload:
            username = payload['username']
        else:
            return response_render(
                'Error: No username option given.',
                http_code='400 Bad Request')

        if PATTERN_USERNAME.match(username) is None or username == 'all':
            return response_render(
                "Error: username doesn't match pattern {}".format(PATTERN_USERNAME.pattern),
                http_code='400 Bad Request')


        if 'realname' in payload:
            realname = unquote_plus(payload['realname'])
        else:
            return response_render(
                'Error: No realname option given.',
                http_code='400 Bad Request')

        if PATTERN_REALNAME.match(realname) is None:
            return response_render(
                "Error: realname doesn't match pattern",
                http_code='400 Bad Request')

        # Get public key
        if 'pubkey' in payload:
            pubkey = unquote_custom(payload['pubkey'])
        else:
            return response_render(
                'Error: No pubkey given.',
                http_code='400 Bad Request')
        tmp_pubkey = NamedTemporaryFile(delete=False)
        tmp_pubkey.write(bytes(pubkey, 'utf-8'))
        tmp_pubkey.close()

        pubkey_fingerprint = get_fingerprint(tmp_pubkey.name)
        if pubkey_fingerprint == 'Unknown':
            remove(tmp_pubkey.name)
            return response_render(
                'Error : Public key unprocessable',
                http_code='422 Unprocessable Entity')

        pg_conn, message = TOOLS.pg_connection()
        if pg_conn is None:
            remove(tmp_pubkey.name)
            return response_render(message, http_code='503 Service Unavailable')
        cur = pg_conn.cursor()

        # Search if key already exists
        cur.execute('SELECT * FROM USERS WHERE NAME=(%s)', (username,))
        user = cur.fetchone()

        # CREATE NEW USER
        if user is None:
            cur.execute('INSERT INTO USERS VALUES \
                ((%s), (%s), (%s), (%s), (%s), (%s), (%s), (%s))', \
                (username, realname, 2, 0, pubkey_fingerprint, pubkey, '+12h', username))
            pg_conn.commit()
            cur.close()
            pg_conn.close()
            remove(tmp_pubkey.name)
            return response_render(
                'Create user=%s. Pending request.' % username,
                http_code='201 Created')
        else:
            # Check if realname is the same
            cur.execute('SELECT * FROM USERS WHERE NAME=(%s) AND REALNAME=lower((%s))', \
                (username, realname))
            if cur.fetchone() is None:
                pg_conn.commit()
                cur.close()
                pg_conn.close()
                remove(tmp_pubkey.name)
                return response_render(
                    'Error : (username, realname) couple mismatch.',
                    http_code='401 Unauthorized')
            # Update entry into database
            cur.execute('UPDATE USERS SET SSH_KEY=(%s), SSH_KEY_HASH=(%s), STATE=2, EXPIRATION=0 \
                WHERE NAME=(%s)', (pubkey, pubkey_fingerprint, username))
            pg_conn.commit()
            cur.close()
            pg_conn.close()
            remove(tmp_pubkey.name)
            return response_render('Update user=%s. Pending request.' % username)


class ClusterStatus():
    """
    ClusterStatus main class.
    """
    def GET(self):
        """
        /cluster/status
        """
        message = dict()
        alive_nodes, dead_nodes = TOOLS.cluster_alived()
        for node in alive_nodes:
            message.update({node: {'status': 'OK'}})
        for node in dead_nodes:
            message.update({node: {'status': 'KO'}})
        return response_render(
            dumps(message),
            content_type='application/json')


class Health():
    """
    Class Health
    """
    def GET(self):
        """
        Return a health check
        """
        health = {}
        health['name'] = 'cassh'
        health['version'] = VERSION
        return response_render(
            dumps(health, indent=4, sort_keys=True),
            content_type='application/json')


class Krl():
    """
    Class KRL.
    """
    def GET(self):
        """
        Return krl.
        """
        return TOOLS.get_last_krl()


class Ping():
    """
    Class Ping
    """
    def GET(self):
        """
        Return a pong
        """
        return response_render('pong')


class Principals():
    """
    Class Principals
    """
    def GET(self, username):
        """
        Get a user principals
        """
        # LDAP authentication
        is_admin_auth, message = ldap_authentification(admin=True)
        if not is_admin_auth:
            return response_render(message, http_code='401 Unauthorized')

        if PATTERN_USERNAME.match(username) is None:
            return response_render(
                "Error: username doesn't match pattern {}".format(PATTERN_USERNAME.pattern),
                http_code='400 Bad Request')
        pg_conn, message = TOOLS.pg_connection()
        if pg_conn is None:
            return response_render(message, http_code='503 Service Unavailable')
        cur = pg_conn.cursor()
        values = {'username': username}
        cur.execute("""SELECT PRINCIPALS FROM USERS WHERE NAME=(%(username)s)""", values)
        principals = cur.fetchone()
        pg_conn.commit()
        cur.close()
        pg_conn.close()
        if not principals:
            return response_render("ERROR: {} doesn't exist or doesn't have principals...".format(
                username), http_code='400 Bad Request')
        return response_render('OK: {} principals are {}'.format(username, principals))

    def POST(self, username):
        """
        Manage user principals
        """
        # LDAP authentication
        is_admin_auth, message = ldap_authentification(admin=True)
        if not is_admin_auth:
            return response_render(message, http_code='401 Unauthorized')

        pg_conn, message = TOOLS.pg_connection()
        if pg_conn is None:
            return response_render(message, http_code='503 Service Unavailable')
        cur = pg_conn.cursor()

        payload = data2map()

        if 'add' not in payload and \
            'remove' not in payload and \
            'update' not in payload and \
            'purge' not in payload:
            return response_render(
                '[ERROR] Unknown action',
                http_code='400 Bad Request')

        if PATTERN_USERNAME.match(username) is None:
            return response_render(
                "Error: username doesn't match pattern {}".format(PATTERN_USERNAME.pattern),
                http_code='400 Bad Request')

        # Search if username exists
        values = {'username': username}
        cur.execute(
            """
            SELECT NAME,PRINCIPALS FROM USERS WHERE NAME=(%(username)s)
            """, values)
        user = cur.fetchone()
        # If user dont exist
        if user is None:
            cur.close()
            pg_conn.close()
            return response_render(
                "ERROR: {} doesn't exist".format(username),
                http_code='400 Bad Request')
        values['principals'] = user[1]

        for key, value in payload.items():
            value = unquote_plus(value)
            if key == 'add':
                for principal in value.split(','):
                    if PATTERN_PRINCIPALS.match(principal) is None:
                        return response_render(
                            "Error: principal doesn't match pattern {}".format(
                                PATTERN_PRINCIPALS.pattern),
                            http_code='400 Bad Request')
                if values['principals']:
                    values['principals'] += ',' + value
                else:
                    values['principals'] = value
            elif key == 'remove':
                principals = values['principals'].split(',')
                for principal in value.split(','):
                    if PATTERN_PRINCIPALS.match(principal) is None:
                        return response_render(
                            "Error: principal doesn't match pattern {}".format(
                                PATTERN_PRINCIPALS.pattern),
                            http_code='400 Bad Request')
                    if principal in principals:
                        principals.remove(principal)
                values['principals'] = ','.join(principals)
            elif key == 'update':
                for principal in value.split(','):
                    if PATTERN_PRINCIPALS.match(principal) is None:
                        return response_render(
                            "Error: principal doesn't match pattern {}".format(
                                PATTERN_PRINCIPALS.pattern),
                            http_code='400 Bad Request')
                values['principals'] = value
            elif key == 'purge':
                values['principals'] = username

        cur.execute(
            """
            UPDATE USERS SET PRINCIPALS=(%(principals)s) WHERE NAME=(%(username)s)
            """, values)
        pg_conn.commit()
        cur.close()
        pg_conn.close()
        return response_render("OK: {} principals are '{}'".format(username, values['principals']))


class PrincipalsSearch():
    """
    Class Principals Search
    """
    def POST(self):
        """
        Search user's principals by filter
        """
        # LDAP authentication
        is_admin_auth, message = ldap_authentification(admin=True)
        if not is_admin_auth:
            return response_render(message, http_code='401 Unauthorized')

        pg_conn, message = TOOLS.pg_connection()
        if pg_conn is None:
            return response_render(message, http_code='503 Service Unavailable')
        cur = pg_conn.cursor()

        payload = data2map()

        if 'filter' not in payload:
            return response_render(
                '[ERROR] Unknown action',
                http_code='400 Bad Request')

        cur.execute(
            """
            SELECT NAME,PRINCIPALS FROM USERS
            """)
        all_principals = cur.fetchall()
        pg_conn.commit()
        cur.close()
        pg_conn.close()

        result = dict()

        for key, value in payload.items():
            value = unquote_plus(value)
            if key == 'filter':
                if value == '':
                    for name, principals in all_principals:
                        result[name] = principals.split(',')
                    continue
                for principal in value.split(','):
                    if PATTERN_PRINCIPALS.match(principal) is None:
                        return response_render(
                            "Error: principal doesn't match pattern {}".format(
                                PATTERN_PRINCIPALS.pattern),
                            http_code='400 Bad Request')
                    for name, principals in all_principals:
                        if principal in principals.split(','):
                            if name not in result:
                                result[name] = list()
                            result[name].append(principal)

        return response_render("OK: {}".format(result))


class TestAuth():
    """
    Test authentication
    """
    def POST(self):
        """
        Test authentication
        """
        # LDAP authentication
        is_auth, message = ldap_authentification()
        if not is_auth:
            return response_render(message, http_code='401 Unauthorized')
        return response_render('OK')


class MyApplication(application):
    """
    Can change port or other stuff
    """
    def run(self, port=int(SERVER_OPTS['port']), *middleware):
        func = self.wsgifunc(*middleware)
        return httpserver.runsimple(func, ('0.0.0.0', port))

if __name__ == "__main__":
    if SERVER_OPTS['ssl']:
        HTTPServer.ssl_adapter = BuiltinSSLAdapter(
            certificate=SERVER_OPTS['ssl_public_key'],
            private_key=SERVER_OPTS['ssl_private_key'])
    if ARGS.verbose:
        print('SSL: %s' % SERVER_OPTS['ssl'])
        print('LDAP: %s' % SERVER_OPTS['ldap'])
        print('Admin DB Failover: %s' % SERVER_OPTS['admin_db_failover'])
    APP = MyApplication(URLS, globals())
    config.debug = SERVER_OPTS['debug']
    if SERVER_OPTS['debug']:
        print('Debug mode on')
    APP.run()
