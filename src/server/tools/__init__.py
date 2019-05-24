#!/usr/bin/env python
""" tools lib """

from __future__ import print_function
from datetime import datetime, timedelta
from json import dumps
from os import stat
from random import choice
from shutil import move
from string import ascii_lowercase
from time import time
from urllib import unquote_plus

# Third party library imports
from psycopg2 import connect, OperationalError, ProgrammingError
from requests import Session
from requests.exceptions import ConnectionError
from web import ctx, header

# Own library
from ssh_utils import Authority

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
        for node in self.server_opts['cluster']:
            req = self.get("%s/ping" % node)
            if req is not None and req.text == 'pong':
                alive_nodes.append(node)
            else:
                dead_nodes.append(node)
        return alive_nodes, dead_nodes


    def cluster_last_krl(self):
        """
        This functions download the biggest KRL of the cluster.
        It's not perfect...
        """
        subset, _ = self.cluster_alived()
        cluster_id = 0
        for node in subset:
            req = self.get("%s/krl" % node)
            with open('/tmp/%s.krl' % cluster_id, 'wb') as cluster_file:
                for chunk in req.iter_content(chunk_size=1024):
                    if chunk: # filter out keep-alive new chunks
                        cluster_file.write(chunk)
            cluster_id += 1

        top_size = stat(self.server_opts['krl']).st_size
        top_cluster_id = 'local'
        for i in range(cluster_id):
            if stat('/tmp/%s.krl' % i).st_size >= top_size:
                top_cluster_id = i

        print('%s KRL is the best' % top_cluster_id)

        if top_cluster_id != 'local':
            move('/tmp/%s.krl' % top_cluster_id, self.server_opts['krl'])
        else:
            self.cluster_updatekrl(None, update_only=True)

        return True


    def cluster_updatekrl(self, username, update_only=False):
        """
        This function send the revokation of a user to the cluster
        """
        subset, _ = self.cluster_alived()
        reqs = list()
        payload = {"clustersecret": self.server_opts['clustersecret']}
        if not update_only:
            payload.update({"username": username})
        for node in subset:
            req = self.post("%s/cluster/updatekrl" % node, payload)
            reqs.append(req)
        return reqs

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
