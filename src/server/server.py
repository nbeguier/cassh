#!/usr/bin/env python
"""
Sign a user's SSH public key.

Copyright 2017 Nicolas BEGUIER
Licensed under the Apache License, Version 2.0
Written by Nicolas BEGUIER (nicolas_beguier@hotmail.com)

"""
# pylint: disable=invalid-name,too-many-return-statements,no-self-use,too-many-locals
# pylint: disable=too-many-branches,too-few-public-methods,too-many-statements
# pylint: disable=too-many-nested-blocks,arguments-differ,W1113

from json import dumps
from os import remove
from tempfile import NamedTemporaryFile
from urllib.parse import unquote_plus

# Third party library imports
from cheroot.server import HTTPServer
from cheroot.ssl.builtin import BuiltinSSLAdapter
import web

# Own library
from ssh_utils import get_fingerprint
import lib.constants as constants
import lib.tools as tools

# DEBUG
# from pdb import set_trace as st

VERSION = '1.12.2'

SERVER_OPTS, ARGS, TOOLS = tools.loadconfig(version=VERSION)

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
        is_admin_auth, message = tools.ldap_authentification(SERVER_OPTS, admin=True)
        if not is_admin_auth:
            return tools.response_render(message, http_code='401 Unauthorized')

        payload, message = tools.data2map()
        if message:
            return tools.response_render(message, http_code='400 Bad Request')

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
            return tools.response_render(message, http_code='503 Service Unavailable')
        cur = pg_conn.cursor()

        if username == 'all' and do_status:
            return tools.response_render(
                TOOLS.list_keys(),
                content_type='application/json')

        # Search if key already exists
        cur.execute(
            """
            SELECT STATE FROM USERS WHERE NAME=(%s)
            """, (username,))
        user_state = cur.fetchone()
        # If user dont exist
        if user_state is None:
            cur.close()
            pg_conn.close()
            message = 'User does not exists.'
        elif do_revoke:
            cur.execute(
                """
                UPDATE USERS SET STATE=1 WHERE NAME=(%s)
                """, (username,))
            pg_conn.commit()
            pubkey = tools.get_pubkey(username, pg_conn)
            cur.execute(
                """
                SELECT 1 FROM REVOCATION WHERE SSH_KEY=(%s)
                """, (pubkey,))
            if cur.fetchone() is None:
                cur.execute(
                    """
                    INSERT INTO REVOCATION VALUES ((%s), (%s), (%s))
                    """, (pubkey, tools.timestamp(), username))
                pg_conn.commit()
                message = 'Revoke user={}.'.format(username)
            else:
                message = 'user {} already revoked.'.format(username)
            cur.close()
            pg_conn.close()
        # Display status
        elif do_status:
            return tools.response_render(
                TOOLS.list_keys(username=username),
                content_type='application/json')
        # If user is in PENDING state
        elif user_state[0] == constants.STATES['PENDING']:
            cur.execute(
                """
                UPDATE USERS SET STATE=0 WHERE NAME=(%s)
                """, (username,))
            pg_conn.commit()
            cur.close()
            pg_conn.close()
            message = 'Active user=%s. SSH Key active but need to be signed.' % username
        # If user is in REVOKED state
        elif user_state[0] == constants.STATES['REVOKED']:
            cur.execute('UPDATE USERS SET STATE=0 WHERE NAME=(%s)', (username,))
            pg_conn.commit()
            cur.close()
            pg_conn.close()
            message = 'Active user=%s. SSH Key active but need to be signed.' % username
        else:
            cur.close()
            pg_conn.close()
            message = 'user=%s already active. Nothing done.' % username
        return tools.response_render(message)

    def PATCH(self, username):
        """
        Set the first founded value.
        /admin/<username>
            key=value => Set the key value. Keys are in status output.
        """
        # LDAP authentication
        is_admin_auth, message = tools.ldap_authentification(SERVER_OPTS, admin=True)
        if not is_admin_auth:
            return tools.response_render(message, http_code='401 Unauthorized')

        pg_conn, message = TOOLS.pg_connection()
        if pg_conn is None:
            return tools.response_render(message, http_code='503 Service Unavailable')
        cur = pg_conn.cursor()

        payload, message = tools.data2map()
        if message:
            return tools.response_render(message, http_code='400 Bad Request')

        for key, value in payload.items():
            if key == 'expiry':
                cur.execute(
                    """
                    UPDATE USERS SET EXPIRY=(%s) WHERE NAME=(%s)
                    """, (value, username))
                pg_conn.commit()
                cur.close()
                pg_conn.close()
                return tools.response_render(
                    'OK: %s=%s for %s' % (key, value, username))
            # Deprecated endpoint for principals
            if key == 'principals':
                value = unquote_plus(value)
                cur.execute(
                    """
                    UPDATE USERS SET PRINCIPALS=(%s) WHERE NAME=(%s)
                    """, (value, username))
                pg_conn.commit()
                cur.close()
                pg_conn.close()
                return tools.response_render(
                    'WARNING: ' + \
                    'This endpoint is deprecated, upgrade your client cassh to 1.7.0\n'+
                    'OK: %s=%s for %s' % (key, value, username))
        return tools.response_render('WARNING: No key found...')

    def DELETE(self, username):
        """
        Delete keys (but DOESN'T REVOKE)
        /admin/<username>
        """
        # LDAP authentication
        is_admin_auth, message = tools.ldap_authentification(SERVER_OPTS, admin=True)
        if not is_admin_auth:
            return tools.response_render(message, http_code='401 Unauthorized')

        pg_conn, message = TOOLS.pg_connection()
        if pg_conn is None:
            return tools.response_render(message, http_code='503 Service Unavailable')
        cur = pg_conn.cursor()

        # Search if key already exists
        cur.execute(
            """
            DELETE FROM USERS WHERE NAME=(%s)
            """, (username,))
        pg_conn.commit()
        cur.close()
        pg_conn.close()
        return tools.response_render('OK')


class Ca():
    """
    Class CA.
    """
    def GET(self):
        """
        Return ca.
        """
        return tools.response_render(
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
        is_auth, message = tools.ldap_authentification(SERVER_OPTS)
        if not is_auth:
            return tools.response_render(message, http_code='401 Unauthorized')

        payload, message = tools.data2map()
        if message:
            return tools.response_render(message, http_code='400 Bad Request')

        if 'realname' in payload:
            realname = unquote_plus(payload['realname'])
        else:
            return tools.response_render(
                'Error: No realname option given.',
                http_code='400 Bad Request')

        return tools.response_render(
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
        is_auth, message = tools.ldap_authentification(SERVER_OPTS)
        if not is_auth:
            return tools.response_render(message, http_code='401 Unauthorized')

        # Check if user is an admin and want to force signature when db fail
        force_sign = False

        # LDAP ADMIN authentication
        is_admin_auth, _ = tools.ldap_authentification(SERVER_OPTS, admin=True)

        payload, message = tools.data2map()
        if message:
            return tools.response_render(message, http_code='400 Bad Request')

        if is_admin_auth and SERVER_OPTS['admin_db_failover'] \
            and 'admin_force' in payload and payload['admin_force'].lower() == 'true':
            force_sign = True

        # Get username
        if 'username' in payload:
            username = payload['username']
        else:
            return tools.response_render(
                'Error: No username option given.',
                http_code='400 Bad Request')
        if username == 'all':
            return tools.response_render(
                "Error: username not valid.",
                http_code='400 Bad Request')

        # Get realname
        if 'realname' in payload:
            realname = unquote_plus(payload['realname'])
        else:
            return tools.response_render(
                'Error: No realname option given.',
                http_code='400 Bad Request')

        # Get public key
        if 'pubkey' in payload:
            pubkey = tools.unquote_custom(payload['pubkey'])
        else:
            return tools.response_render(
                'Error: No pubkey given.',
                http_code='400 Bad Request')
        tmp_pubkey = NamedTemporaryFile(delete=False)
        tmp_pubkey.write(bytes(pubkey, 'utf-8'))
        tmp_pubkey.close()

        pubkey_fingerprint = get_fingerprint(tmp_pubkey.name)
        if pubkey_fingerprint == 'Unknown':
            remove(tmp_pubkey.name)
            return tools.response_render(
                'Error : Public key unprocessable',
                http_code='422 Unprocessable Entity')

        pg_conn, message = TOOLS.pg_connection()
        # Admin force signature case
        if pg_conn is None and force_sign:
            cert_contents = TOOLS.sign_key(tmp_pubkey.name, username, '+12h', username)
            remove(tmp_pubkey.name)
            return tools.response_render(cert_contents, content_type='application/octet-stream')
        # Check if db is up
        if pg_conn is None:
            remove(tmp_pubkey.name)
            return tools.response_render(message, http_code='503 Service Unavailable')
        cur = pg_conn.cursor()

        # Search if key already exists
        cur.execute(
            """
            SELECT NAME,REALNAME,STATE,EXPIRY,PRINCIPALS FROM USERS
            WHERE SSH_KEY=(%s) AND NAME=lower(%s)
            """, (pubkey, username))
        user = cur.fetchone()
        if user is None:
            cur.close()
            pg_conn.close()
            remove(tmp_pubkey.name)
            return tools.response_render(
                'Error : User or Key absent, add your key again.',
                http_code='400 Bad Request')

        if username != user[0] or realname != user[1]:
            cur.close()
            pg_conn.close()
            remove(tmp_pubkey.name)
            return tools.response_render(
                'Error : (username, realname) couple mismatch.',
                http_code='401 Unauthorized')

        status = user[2]
        expiry = user[3]
        principals = tools.get_principals(user[4], username, shell=True)

        if status > 0:
            cur.close()
            pg_conn.close()
            remove(tmp_pubkey.name)
            return tools.response_render("Status: %s" % constants.STATES[user[2]])

        cert_contents = TOOLS.sign_key(
            tmp_pubkey.name, username, expiry, principals, db_cursor=cur)

        remove(tmp_pubkey.name)
        pg_conn.commit()
        cur.close()
        pg_conn.close()
        return tools.response_render(
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
        is_auth, message = tools.ldap_authentification(SERVER_OPTS)
        if not is_auth:
            return tools.response_render(message, http_code='401 Unauthorized')

        payload, message = tools.data2map()
        if message:
            return tools.response_render(message, http_code='400 Bad Request')

        if 'username' in payload:
            username = payload['username']
        else:
            return tools.response_render(
                'Error: No username option given.',
                http_code='400 Bad Request')

        if username == 'all':
            return tools.response_render(
                "Error: username not valid.",
                http_code='400 Bad Request')


        if 'realname' in payload:
            realname = unquote_plus(payload['realname'])
        else:
            return tools.response_render(
                'Error: No realname option given.',
                http_code='400 Bad Request')

        if constants.PATTERN_REALNAME.match(realname) is None:
            return tools.response_render(
                "Error: realname doesn't match pattern",
                http_code='400 Bad Request')

        # Get public key
        if 'pubkey' in payload:
            pubkey = tools.unquote_custom(payload['pubkey'])
        else:
            return tools.response_render(
                'Error: No pubkey given.',
                http_code='400 Bad Request')
        tmp_pubkey = NamedTemporaryFile(delete=False)
        tmp_pubkey.write(bytes(pubkey, 'utf-8'))
        tmp_pubkey.close()

        pubkey_fingerprint = get_fingerprint(tmp_pubkey.name)
        if pubkey_fingerprint == 'Unknown':
            remove(tmp_pubkey.name)
            return tools.response_render(
                'Error : Public key unprocessable',
                http_code='422 Unprocessable Entity')

        pg_conn, message = TOOLS.pg_connection()
        if pg_conn is None:
            remove(tmp_pubkey.name)
            return tools.response_render(message, http_code='503 Service Unavailable')
        cur = pg_conn.cursor()

        # Search if key already exists
        cur.execute(
            """
            SELECT 1 FROM USERS WHERE NAME=(%s)
            """, (username,))
        user = cur.fetchone()
        # CREATE NEW USER
        if user is None:
            cur.execute(
                """
                INSERT INTO USERS VALUES ((%s), (%s), (%s), (%s), (%s), (%s), (%s), (%s))
                """, (
                    username, realname, constants.STATES['PENDING'],
                    0, pubkey_fingerprint, pubkey, '+12h', username))
            pg_conn.commit()
            cur.close()
            pg_conn.close()
            remove(tmp_pubkey.name)
            return tools.response_render(
                'Create user=%s. Pending request.' % username,
                http_code='201 Created')
        # Check if realname is the same
        cur.execute(
            """
            SELECT 1 FROM USERS WHERE NAME=(%s) AND REALNAME=lower((%s))
            """, (username, realname))
        if cur.fetchone() is None:
            pg_conn.commit()
            cur.close()
            pg_conn.close()
            remove(tmp_pubkey.name)
            return tools.response_render(
                'Error : (username, realname) couple mismatch.',
                http_code='401 Unauthorized')
        # Update entry into database
        cur.execute(
            """
            UPDATE USERS
            SET SSH_KEY=(%s),SSH_KEY_HASH=(%s), STATE=(%s), EXPIRATION=0
            WHERE NAME=(%s)
            """, (pubkey, pubkey_fingerprint, constants.STATES['PENDING'], username))
        pg_conn.commit()
        cur.close()
        pg_conn.close()
        remove(tmp_pubkey.name)
        return tools.response_render('Update user=%s. Pending request.' % username)


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
        return tools.response_render(
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
        return tools.response_render(
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
        return tools.response_render('pong')


class Principals():
    """
    Class Principals
    """
    def GET(self, username):
        """
        Get a user principals
        """
        # LDAP authentication
        is_admin_auth, message = tools.ldap_authentification(SERVER_OPTS, admin=True)
        if not is_admin_auth:
            return tools.response_render(message, http_code='401 Unauthorized')

        pg_conn, message = TOOLS.pg_connection()
        if pg_conn is None:
            return tools.response_render(message, http_code='503 Service Unavailable')
        cur = pg_conn.cursor()
        values = {'username': username}
        cur.execute(
            """
            SELECT PRINCIPALS FROM USERS WHERE NAME=(%(username)s)
            """, values)
        principals = cur.fetchone()
        pg_conn.commit()
        cur.close()
        pg_conn.close()
        if not principals:
            return tools.response_render(
                "ERROR: {} doesn't exist or doesn't have principals...".format(
                    username),
                http_code='400 Bad Request')
        return tools.response_render('OK: {} principals are {}'.format(username, principals))

    def POST(self, username):
        """
        Manage user principals
        """
        # LDAP authentication
        is_admin_auth, message = tools.ldap_authentification(SERVER_OPTS, admin=True)
        if not is_admin_auth:
            return tools.response_render(message, http_code='401 Unauthorized')

        pg_conn, message = TOOLS.pg_connection()
        if pg_conn is None:
            return tools.response_render(message, http_code='503 Service Unavailable')
        cur = pg_conn.cursor()

        payload, message = tools.data2map()
        if message:
            return tools.response_render(message, http_code='400 Bad Request')

        if 'add' not in payload and \
            'remove' not in payload and \
            'update' not in payload and \
            'purge' not in payload:
            return tools.response_render(
                '[ERROR] Unknown action',
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
            return tools.response_render(
                "ERROR: {} doesn't exist".format(username),
                http_code='400 Bad Request')
        values['principals'] = user[1]

        for key, value in payload.items():
            value = unquote_plus(value)
            if key == 'add':
                for principal in value.split(','):
                    if constants.PATTERN_PRINCIPALS.match(principal) is None:
                        return tools.response_render(
                            "Error: principal doesn't match pattern {}".format(
                                constants.PATTERN_PRINCIPALS.pattern),
                            http_code='400 Bad Request')
                if values['principals']:
                    values['principals'] += ',' + value
                else:
                    values['principals'] = value
            elif key == 'remove':
                principals = values['principals'].split(',')
                for principal in value.split(','):
                    if constants.PATTERN_PRINCIPALS.match(principal) is None:
                        return tools.response_render(
                            "Error: principal doesn't match pattern {}".format(
                                constants.PATTERN_PRINCIPALS.pattern),
                            http_code='400 Bad Request')
                    if principal in principals:
                        principals.remove(principal)
                values['principals'] = ','.join(principals)
            elif key == 'update':
                for principal in value.split(','):
                    if constants.PATTERN_PRINCIPALS.match(principal) is None:
                        return tools.response_render(
                            "Error: principal doesn't match pattern {}".format(
                                constants.PATTERN_PRINCIPALS.pattern),
                            http_code='400 Bad Request')
                values['principals'] = value
            elif key == 'purge':
                values['principals'] = username

        # Remove duplicates
        values['principals'] = ','.join(list(dict.fromkeys(values['principals'].split(','))))
        cur.execute(
            """
            UPDATE USERS SET PRINCIPALS=(%(principals)s) WHERE NAME=(%(username)s)
            """, values)
        pg_conn.commit()
        cur.close()
        pg_conn.close()
        return tools.response_render(
            "OK: {} principals are '{}'".format(username, values['principals']))


class PrincipalsSearch():
    """
    Class Principals Search
    """
    def POST(self):
        """
        Search user's principals by filter
        """
        # LDAP authentication
        is_admin_auth, message = tools.ldap_authentification(SERVER_OPTS, admin=True)
        if not is_admin_auth:
            return tools.response_render(message, http_code='401 Unauthorized')

        pg_conn, message = TOOLS.pg_connection()
        if pg_conn is None:
            return tools.response_render(message, http_code='503 Service Unavailable')
        cur = pg_conn.cursor()

        payload, message = tools.data2map()
        if message:
            return tools.response_render(message, http_code='400 Bad Request')

        if 'filter' not in payload:
            return tools.response_render(
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
            if key == 'filter' and value == '':
                for name, principals in all_principals:
                    if isinstance(principals, str):
                        result[name] = principals.split(',')
            elif key == 'filter':
                for principal in value.split(','):
                    for name, principals in all_principals:
                        if isinstance(principals, str) and principal in principals.split(','):
                            if name not in result:
                                result[name] = list()
                            result[name].append(principal)

        return tools.response_render(dumps(result))

class TestAuth():
    """
    Test authentication
    """
    def POST(self):
        """
        Test authentication
        """
        # LDAP authentication
        is_auth, message = tools.ldap_authentification(SERVER_OPTS)
        if not is_auth:
            return tools.response_render(message, http_code='401 Unauthorized')
        return tools.response_render('OK')

class MyApplication(web.application):
    """
    Can change port or other stuff
    """
    def run(self, port=int(SERVER_OPTS['port']), *middleware):
        func = self.wsgifunc(*middleware)
        return web.httpserver.runsimple(func, ('0.0.0.0', port))

if __name__ == "__main__":
    if SERVER_OPTS['ssl']:
        HTTPServer.ssl_adapter = BuiltinSSLAdapter(
            certificate=SERVER_OPTS['ssl_public_key'],
            private_key=SERVER_OPTS['ssl_private_key'])
    if ARGS.verbose:
        print('SSL: %s' % SERVER_OPTS['ssl'])
        print('LDAP: %s' % SERVER_OPTS['ldap'])
        print('Admin DB Failover: %s' % SERVER_OPTS['admin_db_failover'])
    APP = MyApplication(constants.URLS, globals(), autoreload=False)
    web.config.debug = SERVER_OPTS['debug']
    if SERVER_OPTS['debug']:
        print('Debug mode on')
    APP.run()
