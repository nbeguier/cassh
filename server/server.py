#!/usr/bin/env python

"""
Sign a user's SSH public key.
"""
from time import time
from hashlib import md5
from os import remove
from sys import argv
from tempfile import NamedTemporaryFile
from web import application, data, httpserver, input as web_input
import ssh_utils
from psycopg2 import connect, OperationalError

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

CA_KEY = argv[1]

def pg_connection(dbname='postgres', user='postgres', host='localhost',\
    password='mysecretpassword'):
    """
    Return a connection to the db
    """
    try:
        pg_conn = connect("dbname='%s' user='%s' host='%s' password='%s'"\
            % (dbname, user, host, password))
    except OperationalError:
        print "I am unable to connect to the database"
        pg_conn = None
    return pg_conn


def list_keys(username=None):
    pg_conn = pg_connection()
    if pg_conn is None:
        return 'I am unable to connect to the database'
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

class AllClientKeys():
    def GET(self):
        return list_keys()

class Client():
    """
    Classe cliente qui demande de signer ou ajouter sa cle publique
    """
    def GET(self, username):
        """
        Return informations
        """
        return list_keys(username=username)


    def POST(self, username):
        pubkey = data()
        pubkey_hash = md5(pubkey).hexdigest()
        tmp_pubkey = NamedTemporaryFile(delete=False)
        tmp_pubkey.write(pubkey)
        tmp_pubkey.close()
        pg_conn = pg_connection()
        if pg_conn is None:
            remove(tmp_pubkey.name)
            return 'I am unable to connect to the database'
        cur = pg_conn.cursor()

        # Search if key already exists
        cur.execute("""SELECT * FROM USERS WHERE SSH_KEY_HASH='%s' AND NAME='%s'""" \
            % (pubkey_hash, username))
        user = cur.fetchone()
        if user is None:
            cur.close()
            pg_conn.close()
            remove(tmp_pubkey.name)
            return 'User absent, try PUT'

        # TODO : Ajouter l'expiration !! user[4]
        if user[1] > 0:
            cur.close()
            pg_conn.close()
            remove(tmp_pubkey.name)
            return "Status: %s" % STATES[user[1]]

        # Load SSH CA
        ca_ssh = ssh_utils.Authority(CA_KEY)

        # Sign the key
        try:
            cert_contents = ca_ssh.sign_public_user_key(\
                tmp_pubkey.name, username, '+1d', username)
            cur.execute("""UPDATE USERS SET STATE=0, EXPIRATION=%s WHERE NAME='%s'""" % (time(), username))
        except:
            cert_contents = 'Error signing key'
        remove(tmp_pubkey.name)
        pg_conn.commit()
        cur.close()
        pg_conn.close()
        return cert_contents

    def PUT(self, username):
        """
        This function permit to add or update a ssh public key
        """
        pubkey = data()
        pubkey_hash = md5(pubkey).hexdigest()
        tmp_pubkey = NamedTemporaryFile(delete=False)
        tmp_pubkey.write(pubkey)
        tmp_pubkey.close()
        pg_conn = pg_connection()
        if pg_conn is None:
            remove(tmp_pubkey.name)
            return 'I am unable to connect to the database'
        cur = pg_conn.cursor()

        # Search if key already exists
        cur.execute("""SELECT * FROM USERS WHERE NAME='%s'""" % username)
        user = cur.fetchone()

        # CREATE NEW USER
        if user is None:
            cur.execute("""INSERT INTO USERS VALUES ('%s', %s, %s, '%s')""" \
                % (username, 2, 0, pubkey_hash))
            pg_conn.commit()
            cur.close()
            pg_conn.close()
            remove(tmp_pubkey.name)
            return 'Create user=%s. Pending request.' % username
        else:
            cur.execute("""UPDATE USERS SET SSH_KEY_HASH='%s', STATE=2, EXPIRATION=0 \
                WHERE NAME = '%s'""" % (pubkey_hash, username))
            pg_conn.commit()
            cur.close()
            pg_conn.close()
            remove(tmp_pubkey.name)
            return 'Update user=%s. Pending request.' % username

class Admin():
    """
    Classe admin pour signer les cles
    """
    def GET(self, username):
        """
        Return informations
        """
        do_sign = web_input('sign')
        pg_conn = pg_connection()
        if pg_conn is None:
            return 'I am unable to connect to the database'
        cur = pg_conn.cursor()

        # Search if key already exists
        cur.execute("""SELECT * FROM USERS WHERE NAME='%s'""" % username)
        user = cur.fetchone()
        # If user dont exist
        if user is None:
            cur.close()
            pg_conn.close()
            return "User '%s' does not exists." % username
        # If user is in PENDING state
        elif user[1] == 2:
            cur.execute("""UPDATE USERS SET STATE=0 WHERE NAME = '%s'""" % username)
            pg_conn.commit()
            cur.close()
            pg_conn.close()
            return 'Active user=%s. SSH Key active but need to be signed.' % username
        # If user is in REVOKE state
        elif user[1] == 1:
            cur.execute("""UPDATE USERS SET STATE=0 WHERE NAME = '%s'""" % username)
            pg_conn.commit()
            cur.close()
            pg_conn.close()
            return 'Active user=%s. SSH Key active but need to be signed.' % username
        else:
            cur.close()
            pg_conn.close()
            return 'user=%s already active. Nothing done.' % username

    def DELETE(self, username):
        pg_conn = pg_connection()
        if pg_conn is None:
            return 'I am unable to connect to the database'
        cur = pg_conn.cursor()

        # Search if key already exists
        cur.execute("""DELETE FROM USERS WHERE NAME='%s'""" % username, )
        pg_conn.commit()
        cur.close()
        pg_conn.close()
        return 'OK'

class Ca():
    """
    Classe CA
    """
    def GET(self):
        """
        Return ca
        """
        return 'TODO'

class Krl():
    """
    Classe KRL
    """
    def GET(self):
        """
        Return krl
        """
        return 'TODO'

class MyApplication(application):
    def run(self, port=8080, *middleware):
        func = self.wsgifunc(*middleware)
        return httpserver.runsimple(func, ('0.0.0.0', port))

if __name__ == "__main__":
    APP = MyApplication(URLS, globals())
    APP.run()
