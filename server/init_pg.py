#!/usr/bin/env python

"""
Init pg database
"""

from __future__ import print_function
from psycopg2 import connect, OperationalError

# DEBUG
# from pdb import set_trace as st

def pg_connection(dbname='postgres', user='postgres', host='localhost',\
    password='mysecretpassword'):
    """
    Return a connection to the db
    """
    try:
        pg_conn = connect("dbname='%s' user='%s' host='%s' password='%s'"\
            % (dbname, user, host, password))
    except OperationalError:
        print('I am unable to connect to the database')
        pg_conn = None
    return pg_conn


def init_pg(pg_conn):
    """
    Initialize pg database
    """
    if pg_conn is None:
        print('I am unable to connect to the database')
        exit(1)
    cur = pg_conn.cursor()
    cur.execute("""CREATE TABLE USERS(
       NAME           TEXT  PRIMARY KEY  NOT NULL,
       REALNAME       TEXT               NOT NULL,
       STATE          INT                NOT NULL,
       EXPIRATION     INT                NOT NULL,
       SSH_KEY_HASH   TEXT,
       SSH_KEY        TEXT,
       EXPIRY         TEXT,
       PRINCIPALS     TEXT,
    )""")

    pg_conn.commit()
    cur.close()
    pg_conn.close()


if __name__ == "__main__":
    init_pg(pg_connection())
