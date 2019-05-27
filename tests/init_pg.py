#!/usr/bin/env python

"""
Init pg database
"""

from __future__ import print_function
from os import listdir
from os.path import isfile, join
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


def init_pg(pg_conn):
    """
    Initialize pg database
    """
    if pg_conn is None:
        print('I am unable to connect to the database')
        exit(1)
    cur = pg_conn.cursor()

    sql_files = [f for f in listdir(SQL_SERVER_PATH) if isfile(join(SQL_SERVER_PATH, f))]

    for sql_file in sql_files:
        with open('%s/%s' % (SQL_SERVER_PATH, sql_file), 'r') as sql_model_file:
            cur.execute(sql_model_file.read())
            pg_conn.commit()

    cur.close()
    pg_conn.close()


if __name__ == "__main__":
    init_pg(pg_connection())
