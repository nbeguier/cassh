#!/usr/bin/env python
"""
tools lib

Copyright 2017 Nicolas BEGUIER
Licensed under the Apache License, Version 2.0
Written by Nicolas BEGUIER (nicolas_beguier@hotmail.com)

"""
# pylint: disable=too-many-branches,too-many-statements,too-many-return-statements
# pylint: disable=broad-except,too-many-arguments,no-name-in-module

from argparse import ArgumentParser
from datetime import datetime, timedelta
from glob import glob
import json
from random import choice
from shutil import copyfile
from string import ascii_lowercase
from tempfile import NamedTemporaryFile
from os.path import isfile
from os import remove
import sys
from time import time
from urllib.parse import unquote_plus

# Third party library imports
from configparser import ConfigParser, NoOptionError
from ldap import initialize, NO_SUCH_OBJECT, SCOPE_SUBTREE
from psycopg2 import connect, OperationalError, ProgrammingError
from requests import Session
from requests.exceptions import ConnectionError as req_ConnectionError
from web import data, ctx, header

# Own library
from ssh_utils import Authority
import lib.constants as constants

# DEBUG
# from pdb import set_trace as st

def loadconfig(version='Unknown'):
    """
    Config loader
    """
    parser = ArgumentParser()
    parser.add_argument('-c', '--config', action='store', help='Configuration file')
    parser.add_argument(
        '-v', '--verbose', action='store_true', default=False,
        help='Add verbosity')
    args = parser.parse_args()

    if not args.config:
        parser.error('--config argument is required !')

    config = ConfigParser()
    config.read(args.config)
    server_opts = {}
    server_opts['ca'] = config.get('main', 'ca')
    server_opts['krl'] = config.get('main', 'krl')
    server_opts['port'] = config.get('main', 'port')

    try:
        server_opts['admin_db_failover'] = config.get('main', 'admin_db_failover')
    except NoOptionError:
        server_opts['admin_db_failover'] = False
    server_opts['ldap'] = False
    server_opts['ssl'] = False
    server_opts['ldap_mapping'] = dict()

    if config.has_section('postgres'):
        try:
            server_opts['db_host'] = config.get('postgres', 'host')
            server_opts['db_name'] = config.get('postgres', 'dbname')
            server_opts['db_user'] = config.get('postgres', 'user')
            server_opts['db_password'] = config.get('postgres', 'password')
        except NoOptionError:
            if args.verbose:
                print('Option reading error (postgres).')
            sys.exit(1)

    if config.has_section('ldap'):

        # Future deprecation of this block
        # START
        try:
            config.get('ldap', 'filterstr')
            print('WARNING: "filterstr" is deprecated, use "filter_realname_key" instead')
        except NoOptionError:
            pass
        # END

        try:
            server_opts['ldap'] = True
            server_opts['ldap_host'] = config.get('ldap', 'host')
            server_opts['ldap_bind_dn'] = config.get('ldap', 'bind_dn')
            server_opts['ldap_username'] = config.get('ldap', 'username')
            server_opts['ldap_password'] = config.get('ldap', 'password')
            server_opts['ldap_admin_cn'] = config.get('ldap', 'admin_cn')
            server_opts['ldap_filter_realname_key'] = config.get('ldap', 'filter_realname_key')
        except NoOptionError:
            if args.verbose:
                print('Option reading error (ldap).')
            sys.exit(1)
        try:
            server_opts['ldap_username_prefix'] = config.get('ldap', 'username_prefix')
        except NoOptionError:
            server_opts['ldap_username_prefix'] = ''
        try:
            server_opts['ldap_username_suffix'] = config.get('ldap', 'username_suffix')
        except NoOptionError:
            server_opts['ldap_username_suffix'] = ''
        try:
            server_opts['ldap_filter_memberof_key'] = config.get('ldap', 'filter_memberof_key')
        except NoOptionError:
            server_opts['ldap_filter_memberof_key'] = 'memberOf'
        try:
            ldap_mapping_path = config.get('ldap', 'ldap_mapping_path')
            if isfile(ldap_mapping_path):
                with open(ldap_mapping_path, 'r') as ldap_mapping_file:
                    server_opts['ldap_mapping'] = json.loads(ldap_mapping_file.read())
        except (NoOptionError, json.decoder.JSONDecodeError):
            pass

    if config.has_section('ssl'):
        try:
            server_opts['ssl'] = True
            server_opts['ssl_private_key'] = config.get('ssl', 'private_key')
            server_opts['ssl_public_key'] = config.get('ssl', 'public_key')
        except NoOptionError:
            if args.verbose:
                print('Option reading error (ssl).')
            sys.exit(1)

    # Cluster mode is used for revocation
    try:
        server_opts['cluster'] = config.get('main', 'cluster').split(',')
    except NoOptionError:
        # Standalone mode
        proto = 'http'
        if server_opts['ssl']:
            proto = 'https'
        server_opts['cluster'] = ['%s://localhost:%s' % (proto, server_opts['port'])]

    try:
        server_opts['clustersecret'] = config.get('main', 'clustersecret')
    except NoOptionError:
        # Standalone mode
        server_opts['clustersecret'] = random_string(32)

    try:
        server_opts['debug'] = bool(config.get('main', 'debug') != 'False')
    except NoOptionError:
        server_opts['debug'] = False

    tooling = Tools(server_opts, constants.STATES, version)
    return server_opts, args, tooling

def get_ldap_conn(host, username, password, reuse=None):
    """
    Returns an LDAP connection
    """
    if reuse:
        ldap_conn = reuse
    else:
        ldap_conn = initialize("ldap://"+host)
    try:
        ldap_conn.bind_s(username, password)
    except Exception as err_msg:
        return False, 'Error: {}'.format(err_msg)
    return ldap_conn, None

def get_memberof(realname, server_options, reuse=None):
    """
    Returns the list of memberOf groups
    """
    if not server_options['ldap']:
        return list(), None
    if reuse:
        ldap_conn = reuse
    else:
        ldap_conn, err_msg = get_ldap_conn(
            server_options['ldap_host'],
            server_options['ldap_username'],
            server_options['ldap_password'])
        if err_msg:
            return list(), 'Error: wrong cassh ldap credentials'
    try:
        output = ldap_conn.search_s(
            server_options['ldap_bind_dn'],
            SCOPE_SUBTREE,
            filterstr='(&({}={}))'.format(
                server_options['ldap_filter_realname_key'],
                realname))
    except NO_SUCH_OBJECT:
        return list(), 'Error: admin LDAP filter is incorrect (no such object).'
    if not isinstance(output, list) or not output:
        return list(), None
    if len(output) != 1:
        return list(), 'Error: admin LDAP filter is incorrect (multiple user).'
    ldap_infos = output[0]
    if not isinstance(output, list) or not output:
        return list(), None
    for i in ldap_infos:
        if isinstance(i, dict) and server_options['ldap_filter_memberof_key'] in i:
            if isinstance(i[server_options['ldap_filter_memberof_key']], list):
                return i[server_options['ldap_filter_memberof_key']], None
            return list(), 'Error: admin LDAP output is incorrect.'
    return list(), 'Error: admin LDAP filter is incorrect.'

def ldap_authentification(server_options, admin=False):
    """
    Return True if user is well authentified
        realname=xxxxx@domain.fr
        password=xxxxx
    It returns also a list of memberof
    """
    if not server_options['ldap']:
        return True, 'OK'
    credentials, message = data2map()
    if message:
        return False, response_render(message, http_code='400 Bad Request')
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

    # user login to validate password
    ldap_conn, err_msg = get_ldap_conn(
        server_options['ldap_host'],
        '{}{}{}'.format(
            server_options['ldap_username_prefix'],
            realname,
            server_options['ldap_username_suffix']),
        password)
    if err_msg:
        return False, err_msg

    # cassh service login
    ldap_conn, err_msg = get_ldap_conn(
        server_options['ldap_host'],
        server_options['ldap_username'],
        server_options['ldap_password'],
        reuse=ldap_conn)
    if err_msg:
        return False, 'Error: wrong cassh ldap credentials'

    list_membership, err_msg = get_memberof(
        realname,
        server_options,
        reuse=ldap_conn)
    if err_msg:
        return False, err_msg

    if admin:
        if server_options['ldap_admin_cn'].encode() not in list_membership:
            return False, 'Error: Not authorized.'
    return True, 'OK'

def validate_payload(key, value):
    """
    Return an error message if invalid input
    """
    new_value = unquote_plus(value)
    count = 10
    while value != new_value and count > 0 and \
        key in ['username', 'principals', 'add', 'remove', 'update', 'filter', 'realname']:
        value = new_value
        new_value = unquote_plus(value)
        count -= 1

    err_msg = None

    if key == 'username' and constants.PATTERN_USERNAME.match(value) is None:
        err_msg = "Error: invalid username."
    elif key == 'realname' and constants.PATTERN_REALNAME.match(value) is None:
        err_msg = "Error: invalid realname."
    elif key == 'expiry' and constants.PATTERN_EXPIRY.match(value) is None:
        err_msg = "Error: invalid expiry."
    elif key in ['principals', 'add', 'remove', 'update']:
        for principal in value.split(','):
            if constants.PATTERN_PRINCIPALS.match(principal) is None:
                err_msg = "Error: invalid principals."
    elif key == 'filter':
        if value != '':
            for principal in value.split(','):
                if constants.PATTERN_PRINCIPALS.match(principal) is None:
                    err_msg = "Error: invalid filter."
    return err_msg

def data2map():
    """
    Returns a map from data POST and error
    """
    data_map = {}
    data_str = data().decode('utf-8')
    if data_str == '':
        return data_map, None
    for key in data_str.split('&'):
        sub_key = key.split('=')[0]
        value = '='.join(key.split('=')[1:])
        message = validate_payload(sub_key, value)
        if message:
            return None, message
        data_map[sub_key] = value
    return data_map, None

def clean_principals_output(sql_result, username, shell=False):
    """
    Transform sql principals into readable one
    """
    if not sql_result:
        if shell:
            return username
        return [username]
    if shell:
        return sql_result
    return sql_result.split(',')

def truncate_principals(custom_principals, list_membership, server_options):
    """
    Returns custom_principals without LDAP principals
    """
    if not custom_principals:
        return ''
    principals = custom_principals.split(',')
    if not server_options['ldap_mapping']:
        return ','.join(principals)
    for user_group_cn in list_membership:
        user_group_cn_decoded = user_group_cn.decode(errors='ignore')
        if user_group_cn_decoded not in server_options['ldap_mapping']:
            continue
        ldap_mapping_principals = server_options['ldap_mapping'][user_group_cn_decoded]
        for principal in ldap_mapping_principals:
            err_msg = validate_payload('principals', principal)
            if err_msg:
                print('Error: Invalid LDAP mapping configuration: err={}, principals={}'.format(
                    err_msg, principal))
                continue
            if principal in principals:
                principals.remove(principal)
    # Remove duplicates
    principals = list(dict.fromkeys(principals))
    return ','.join(principals)

def merge_principals(custom_principals, list_membership, server_options):
    """
    Returns a custom_principals + LDAP principals
    """
    if not custom_principals:
        return ''
    principals = custom_principals.split(',')
    if not server_options['ldap_mapping']:
        return ','.join(principals)
    for user_group_cn in list_membership:
        user_group_cn_decoded = user_group_cn.decode(errors='ignore')
        if user_group_cn_decoded not in server_options['ldap_mapping']:
            continue
        ldap_mapping_principals = server_options['ldap_mapping'][user_group_cn_decoded]
        for principal in ldap_mapping_principals:
            err_msg = validate_payload('principals', principal)
            if err_msg:
                print('Error: Invalid LDAP mapping configuration: err={}, principals={}'.format(
                    err_msg, principal))
                continue
            principals.append(principal)
    # Remove duplicates
    principals = list(dict.fromkeys(principals))
    return ','.join(principals)

def get_pubkey(username, pg_conn, key_n=0):
    """
    Returns the public key stored in the USERS database
    For now, there is only one key per user, but it could change in the future
    """
    cur = pg_conn.cursor()
    cur.execute(
        """
        SELECT SSH_KEY FROM USERS WHERE NAME=(%s)
        """, (username,))
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


class Tools():
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
        except req_ConnectionError:
            print('Connection error : %s' % url)
            req = None
        return req

    def get_last_krl(self):
        """
        Generates or returns a KRL file
        """
        pg_conn, message = self.pg_connection()
        if pg_conn is None:
            return response_render(message, http_code='503 Service Unavailable')
        cur = pg_conn.cursor()
        cur.execute(
            """
            SELECT MAX(REVOCATION_DATE) FROM REVOCATION
            """)
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
        except req_ConnectionError:
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
        except Exception:
            cert_contents = 'Error : signing key'
        return cert_contents

    def sql_to_json(self, result, is_list=False):
        """
        This function prettify a sql result into json
        """
        if result is None:
            return None
        ldap_conn = None
        if self.server_opts['ldap']:
            ldap_conn, _ = get_ldap_conn(
                self.server_opts['ldap_host'],
                self.server_opts['ldap_username'],
                self.server_opts['ldap_password'])
        if is_list:
            d_result = {}
            for res in result:
                d_sub_result = {}
                d_sub_result['username'] = res[0]
                d_sub_result['realname'] = res[1]
                d_sub_result['status'] = self.states[res[2]]
                d_sub_result['expiration'] = datetime.fromtimestamp(res[3]).strftime(
                    '%Y-%m-%d %H:%M:%S')
                d_sub_result['ssh_key_hash'] = pretty_ssh_key_hash(res[4])
                d_sub_result['expiry'] = res[6]
                list_membership, _ = get_memberof(
                    res[1],
                    self.server_opts,
                    reuse=ldap_conn)
                full_principals = merge_principals(res[7], list_membership, self.server_opts)
                d_sub_result['principals'] = clean_principals_output(full_principals, res[0])
                d_result[res[0]] = d_sub_result
            return json.dumps(d_result, indent=4, sort_keys=True)
        d_result = {}
        d_result['username'] = result[0]
        d_result['realname'] = result[1]
        d_result['status'] = self.states[result[2]]
        d_result['expiration'] = datetime.fromtimestamp(result[3]).strftime(
            '%Y-%m-%d %H:%M:%S')
        d_result['ssh_key_hash'] = pretty_ssh_key_hash(result[4])
        d_result['expiry'] = result[6]
        list_membership, _ = get_memberof(
            result[1],
            self.server_opts,
            reuse=ldap_conn)
        full_principals = merge_principals(result[7], list_membership, self.server_opts)
        d_result['principals'] = clean_principals_output(full_principals, result[0])
        return json.dumps(d_result, indent=4, sort_keys=True)
