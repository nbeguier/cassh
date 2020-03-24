#!/usr/bin/env python
"""
tools lib

Copyright 2017 Nicolas BEGUIER
Licensed under the Apache License, Version 2.0
Written by Nicolas BEGUIER (nicolas_beguier@hotmail.com)

"""

from datetime import datetime, timedelta
from glob import glob
from json import dumps
from os import remove, stat
from random import choice
from shutil import copyfile, move
from string import ascii_lowercase
from tempfile import NamedTemporaryFile
from time import time
from urllib.parse import unquote_plus

# Third party library imports
from psycopg2 import connect, OperationalError, ProgrammingError
from requests import Session
from requests.exceptions import ConnectionError
from web import ctx, header

# Own library
from ssh_utils import Authority

# DEBUG
# from pdb import set_trace as st

def get_principals(sql_result, username, shell=False):
    """
    Transform sql principals into readable one
    """
    if sql_result is None or sql_result == '':
        if shell:
            return username
        return [username]
    else:
        if shell:
            return sql_result
        return sql_result.split(',')

def get_pubkey(username, pg_conn, key_n=0):
    """
    Returns the public key stored in the USERS database
    For now, there is only one key per user, but it could change in the future
    """
    cur = pg_conn.cursor()
    cur.execute('SELECT SSH_KEY FROM USERS WHERE NAME=(%s)', (username,))
    pubkeys = cur.fetchall()
    cur.close()

    if len(pubkeys) <= key_n:
        return None
    if not pubkeys[key_n]:
        return None
    pubkey = pubkeys[key_n][0]

    return pubkey

def pretty_ssh_key_hash(pubkey_fingerprint):
    """
    Returns a pretty json from raw pubkey
    KEY_BITS KEY_HASH [JERK] (AUTH_TYPE)
    """
    try:
        key_bits = int(pubkey_fingerprint.split(' ')[0])
    except ValueError:
        key_bits = 0
    except IndexError:
        key_bits = 0

    try:
        key_hash = pubkey_fingerprint.split(' ')[1]
    except IndexError:
        key_hash = pubkey_fingerprint

    try:
        auth_type = pubkey_fingerprint.split('(')[-1].split(')')[0]
    except IndexError:
        auth_type = 'Unknown'

    rate = 'UNKNOWN'
    if auth_type == 'DSA':
        rate = 'VERY LOW'
    elif (auth_type == 'RSA' and key_bits >= 4096) or (auth_type == 'ECDSA' and key_bits >= 256):
        rate = 'HIGH'
    elif auth_type == 'RSA' and key_bits >= 2048:
        rate = 'MEDIUM'
    elif auth_type == 'RSA' and key_bits < 2048:
        rate = 'LOW'
    elif auth_type == 'ED25519' and key_bits >= 256:
        rate = 'VERY HIGH'

    return {'bits': key_bits, 'hash': key_hash, 'auth_type': auth_type, 'rate': rate}

def random_string(string_length=10):
    """Generate a random string of fixed length """
    letters = ascii_lowercase
    return ''.join(choice(letters) for i in range(string_length))

def response_render(message, http_code='200 OK', content_type='text/plain'):
    """
    This function returns a well-formed HTTP response
    """
    header('Content-Type', content_type)
    ctx.status = http_code
    return message

def str2date(string):
    """
    change xd => seconds
    change xh => seconds
    """
    delta = 0
    if 'd' in string:
        delta = timedelta(days=int(string.split('d')[0])).total_seconds()
    elif 'h' in string:
        delta = timedelta(hours=int(string.split('h')[0])).total_seconds()
    return delta

def timestamp():
    """
    Returns the epoch time of now
    """
    return time()

def unquote_custom(string):
    """
    Returns True is the string is quoted
    """
    if ' ' not in string:
        string = unquote_plus(string)
        if '+' in string and '%20' in string:
            # Old custom quote
            string = string.replace('%20', ' ')
    return string


class Tools(object):
    """
    Class tools
    """
    def __init__(self, server_opts, states, version):
        self.server_opts = server_opts
        self.states = states
        self.version = version
        self.req_headers = {
            'User-Agent': 'CASSH-SERVER v%s' % version,
            'SERVER_VERSION': version,
        }
        self.req_timeout = 2

    def cluster_alived(self):
        """
        This function returns a subset of pingeable node
        """
        alive_nodes = list()
        dead_nodes = list()
        if not self.server_opts['cluster'] or \
            self.server_opts['cluster'] == ['']:
            return alive_nodes, dead_nodes
        for node in self.server_opts['cluster']:
            req = self.get("%s/ping" % node)
            if req is not None and req.text == 'pong':
                alive_nodes.append(node)
            else:
                dead_nodes.append(node)
        return alive_nodes, dead_nodes

    def get(self, url):
        """
        Rebuilt GET function for CASSH purpose
        """
        session = Session()
        try:
            req = session.get(url,
                              headers=self.req_headers,
                              timeout=self.req_timeout,
                              stream=True)
        except ConnectionError:
            print('Connection error : %s' % url)
            req = None
        return req

    def get_last_krl(self):
        """
        Generates or returns a KRL file
        """
        from os.path import isfile

        pg_conn, message = self.pg_connection()
        if pg_conn is None:
            return response_render(message, http_code='503 Service Unavailable')
        cur = pg_conn.cursor()
        cur.execute('SELECT MAX(REVOCATION_DATE) FROM REVOCATION')
        last_timestamp = cur.fetchone()
        if not last_timestamp[0]:
            return response_render(
                open(self.server_opts['krl'], 'rb'),
                content_type='application/octet-stream')

        last_krl = '%s.%s' % (self.server_opts['krl'], last_timestamp[0])

        # Check if the KRL is up-to-date
        if not isfile(last_krl):
            ca_ssh = Authority(self.server_opts['ca'], last_krl)
            ca_ssh.generate_empty_krl()

            cur.execute('SELECT SSH_KEY FROM REVOCATION')
            pubkeys = cur.fetchall()

            if not pubkeys or not pubkeys[0]:
                cur.close()
                pg_conn.close()
                return response_render(
                    open(self.server_opts['krl'], 'rb'),
                    content_type='application/octet-stream')

            for pubkey in pubkeys:
                tmp_pubkey = NamedTemporaryFile(delete=False)
                tmp_pubkey.write(bytes(pubkey[0], 'utf-8'))
                tmp_pubkey.close()
                ca_ssh.update_krl(tmp_pubkey.name)
            remove(tmp_pubkey.name)

            copyfile(last_krl, self.server_opts['krl'])

        # Clean old files
        old_files = glob('%s*' % self.server_opts['krl'])
        old_files.remove(self.server_opts['krl'])
        old_files.remove(last_krl)
        for old_file in old_files:
            remove(old_file)

        cur.close()
        pg_conn.close()

        return response_render(
            open(self.server_opts['krl'], 'rb'),
            content_type='application/octet-stream')

    def list_keys(self, username=None, realname=None):
        """
        Return all keys.
        """
        pg_conn, message = self.pg_connection()
        if pg_conn is None:
            return response_render(message, http_code='503 Service Unavailable')
        cur = pg_conn.cursor()
        is_list = False

        if realname is not None:
            cur.execute('SELECT * FROM USERS WHERE REALNAME=lower((%s))', (realname,))
            result = cur.fetchone()
        elif username is not None:
            cur.execute('SELECT * FROM USERS WHERE NAME=(%s)', (username,))
            result = cur.fetchone()
        else:
            cur.execute('SELECT * FROM USERS')
            result = cur.fetchall()
            is_list = True
        cur.close()
        pg_conn.close()
        return self.sql_to_json(result, is_list=is_list)

    def pg_connection(self):
        """
        Return a connection to the db.
        """
        dbname = self.server_opts['db_name']
        user = self.server_opts['db_user']
        host = self.server_opts['db_host']
        password = self.server_opts['db_password']
        message = ''
        try:
            pg_conn = connect("dbname='%s' user='%s' host='%s' password='%s'"\
                % (dbname, user, host, password))
        except OperationalError:
            return None, 'Error : Server cannot connect to database'
        try:
            pg_conn.cursor().execute("""SELECT * FROM USERS""")
        except ProgrammingError:
            return None, 'Error : Server cannot connect to table in database'
        return pg_conn, message

    def post(self, url, payload):
        """
        Rebuilt POST function for CASSH purpose
        """
        session = Session()
        try:
            req = session.post(url,
                               data=payload,
                               headers=self.req_headers,
                               timeout=self.req_timeout)
        except ConnectionError:
            print('Connection error : %s' % url)
            req = None
        return req

    def sign_key(self, tmp_pubkey_name, username, expiry, principals, db_cursor=None):
        """
        Sign a key and return cert_contents
        """
        # Load SSH CA
        ca_ssh = Authority(self.server_opts['ca'], self.server_opts['krl'])

        # Sign the key
        try:
            cert_contents = ca_ssh.sign_public_user_key(\
                tmp_pubkey_name, username, expiry, principals)
            if db_cursor is not None:
                db_cursor.execute('UPDATE USERS SET STATE=0, EXPIRATION=(%s) WHERE NAME=(%s)', \
                    (time() + str2date(expiry), username))
        except:
            cert_contents = 'Error : signing key'
        return cert_contents

    def sql_to_json(self, result, is_list=False):
        """
        This function prettify a sql result into json
        """
        if result is None:
            return None
        if is_list:
            d_result = {}
            for res in result:
                d_sub_result = {}
                d_sub_result['username'] = res[0]
                d_sub_result['realname'] = res[1]
                d_sub_result['status'] = self.states[res[2]]
                d_sub_result['expiration'] = datetime.fromtimestamp(res[3]).strftime('%Y-%m-%d %H:%M:%S')
                d_sub_result['ssh_key_hash'] = pretty_ssh_key_hash(res[4])
                d_sub_result['expiry'] = res[6]
                d_sub_result['principals'] = get_principals(res[7], res[0])
                d_result[res[0]] = d_sub_result
            return dumps(d_result, indent=4, sort_keys=True)
        d_result = {}
        d_result['username'] = result[0]
        d_result['realname'] = result[1]
        d_result['status'] = self.states[result[2]]
        d_result['expiration'] = datetime.fromtimestamp(result[3]).strftime('%Y-%m-%d %H:%M:%S')
        d_result['ssh_key_hash'] = pretty_ssh_key_hash(result[4])
        d_result['expiry'] = result[6]
        d_result['principals'] = get_principals(result[7], result[0])
        return dumps(d_result, indent=4, sort_keys=True)
