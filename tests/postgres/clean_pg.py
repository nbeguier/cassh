#!/usr/bin/env python

"""
Clean pg database
"""

import sys

# Third party library imports
from psycopg2 import connect, OperationalError

# DEBUG
# from pdb import set_trace as st

SQL_SERVER_PATH = 'src/server/sql'

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

def clean_pg(pg_conn):
    """
    Clean pg database
    """
    if pg_conn is None:
        print('I am unable to connect to the database')
        sys.exit(1)
    cur = pg_conn.cursor()

    cur.execute(
        """
        DELETE FROM USERS
        """)
    cur.execute(
        """
        DELETE FROM REVOCATION
        """)
    pg_conn.commit()

    cur.close()
    pg_conn.close()


if __name__ == "__main__":
    clean_pg(pg_connection())
