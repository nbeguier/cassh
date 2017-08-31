#!/usr/bin/python3
#-*- coding: utf-8 -*-
""" cassh_html """

from __future__ import print_function


import os
import yaml
import logging
import datetime
import markdown
from urllib.parse import urljoin
from datetime import timedelta
from werkzeug import secure_filename
from werkzeug.contrib.atom import AtomFeed
from flask import Flask, render_template, Markup, abort, redirect, url_for, request, flash
import requests



# Standard library imports
from argparse import ArgumentParser
from codecs import getwriter
from datetime import datetime
from getpass import getpass
from json import dumps, loads
from os import chmod, getenv
from os.path import isfile
from shutil import copyfile
import sys

# Third party library imports
from configparser import ConfigParser, NoOptionError, NoSectionError
from requests import Session
from requests.exceptions import ConnectionError
from urllib3 import disable_warnings

# Disable HTTPs warnings
disable_warnings()

from pdb import set_trace as st

app = Flask(__name__)
app.config.from_pyfile('settings.py')


logger = logging.getLogger(__name__)

cache = {}

def read_conf(conf_path):
    """
    Read CASSH configuration file and return metadata.
    """
    config = ConfigParser()
    config.read(conf_path)
    user_metadata = {}
    try:
        user_metadata['name'] = config.get('user', 'name')
        user_metadata['key_path'] = config.get('user', 'key_path')\
        .replace('~', getenv('HOME'))
        user_metadata['key_signed_path'] = config.get('user', 'key_signed_path')\
        .replace('~', getenv('HOME'))
        user_metadata['url'] = config.get('user', 'url')
    except NoOptionError as error_msg:
        print('Can\'t read configuration file...')
        print(error_msg)
        exit(1)

    if user_metadata['key_path'] == user_metadata['key_signed_path']:
        print('You should put a different path for key_path and key_signed_path.')
        exit(1)

    try:
        user_metadata['auth'] = 'ldap'
        user_metadata['realname'] = config.get('ldap', 'realname')
    except NoOptionError as error_msg:
        print('Can\'t read configuration file...')
        print(error_msg)
        exit(1)
    except NoSectionError:
        user_metadata['auth'] = None
        user_metadata['realname'] = None

    if not isfile(user_metadata['key_path']):
        print('File %s doesn\'t exists' % user_metadata['key_path'])
        exit(1)

    return user_metadata

class CASSH(object):
    """
    Main CASSH class.
    """
    def __init__(self, user_metadata):
        """
        Init file.
        """
        self.name = user_metadata['name']
        self.key_path = user_metadata['key_path']
        self.key_signed_path = user_metadata['key_signed_path']
        self.session = Session()
        self.url = user_metadata['url']
        self.auth = user_metadata['auth']
        self.realname = user_metadata['realname']


    def auth_url(self, prefix=None):
        """
        Return a ?xxx=xxx to put at the end of a GET request.
        """
        passwd_message = 'Please type your LDAP password (user=%s): ' % self.realname
        if self.auth == 'ldap':
            if prefix is None:
                return '?realname=%s&password=%s'\
                    % (self.realname, getpass(passwd_message))
            else:
                return prefix + '&realname=%s&password=%s'\
                    % (self.realname, getpass(passwd_message))
        else:
            if prefix is None:
                return ''
            else:
                return prefix

    def admin(self, username, action):
        """
        Admin CLI
        """
        try:
            if action == 'revoke':
                req = self.session.get(self.url + '/admin/' + username +\
                    self.auth_url(prefix='?revoke=true'), verify=False)
            elif action == 'active':
                req = self.session.get(self.url + '/admin/' + username +\
                    self.auth_url(prefix='?revoke=false'), verify=False)
            elif action == 'delete':
                req = self.session.delete(self.url + '/admin/' + username +\
                    self.auth_url(), verify=False)
            elif action == 'status':
                req = self.session.get(self.url + '/client' +\
                    self.auth_url(prefix='?username=%s' % username), verify=False)
            else:
                print('Action should be : revoke, active, delete or status')
                exit(1)
        except ConnectionError:
            print('Connection error : %s' % self.url)
            exit(1)
        print(req.text)

    def add(self):
        """
        Add a public key.
        """
        pubkey = open('%s.pub' % self.key_path, 'rb')
        try:
            req = self.session.put(self.url + '/client/' + self.name +\
                self.auth_url(), data=pubkey, verify=False)
        except ConnectionError:
            print('Connection error : %s' % self.url)
            exit(1)
        print(req.text)

    def sign(self, do_write_on_disk):
        """
        Sign a public key.
        """
        pubkey = open('%s.pub' % self.key_path, 'rb')
        try:
            req = self.session.post(self.url + '/client/' + self.name +\
                self.auth_url(), data=pubkey, verify=False)
        except ConnectionError:
            print('Connection error : %s' % self.url)
            exit(1)
        if 'Error' in req.text:
            print(req.text)
            exit(1)
        if do_write_on_disk:
            copyfile(self.key_path, self.key_signed_path)
            chmod(self.key_signed_path, 600)
            pubkey_signed = open('%s.pub' % self.key_signed_path, 'w+')
            pubkey_signed.write(req.text)
            pubkey_signed.close()
            print('Public key successfuly signed')
        else:
            print(req.text)

    def status(self):
        """
        Get status of public key.
        """
        try:
            req = self.session.get(self.url + '/client/' + self.name + self.auth_url(),\
                verify=False)
        except ConnectionError:
            print('Connection error : %s' % self.url)
            exit(1)
        result = loads(req.text)
        is_expired = datetime.strptime(result['expiration'], '%Y-%m-%d %H:%M:%S') < datetime.now()
        if result['status'] == 'ACTIVE':
            if is_expired:
                result['status'] = 'EXPIRED'
            else:
                result['status'] = 'SIGNED'
        return dumps(result, indent=4, sort_keys=True)

    def get_ca(self):
        """
        Get CA public key.
        """
        try:
            req = self.session.get(self.url + '/ca', verify=False)
        except ConnectionError:
            print('Connection error : %s' % self.url)
            exit(1)
        return req.text

    def get_krl(self):
        """
        Get CA KRL.
        """
        try:
            req = self.session.get(self.url + '/krl', verify=False)
        except ConnectionError:
            print('Connection error : %s' % self.url)
            exit(1)
        return req.text

CONF_FILE = '%s/.cassh' % getenv('HOME')
LBC = CASSH(read_conf(CONF_FILE))


def get_page(directory, file):
    """Load and parse a page from the filesystem. Returns the page, or None if not found"""
    filename = secure_filename(file)

    if filename in cache:
        return cache[filename]

    path = os.path.abspath(os.path.join(os.path.dirname(__file__), directory, filename))
    try:
        file_contents = open(path, encoding='utf-8').read()
    except:
        logger.exception("Failed to open file at path: %s", path)
        return None
    data, text = file_contents.split('---\n', 1)
    page = yaml.load(data)
    page['content'] = Markup(markdown.markdown(text))
    page['path'] = file

    cache[filename] = page
    return page


@app.route('/')
def index():
    return render_template('homepage.html')


@app.route('/add/')
def cassh_add():
    return render_template('add.html')


@app.route('/sign/')
def cassh_sign():
    return render_template('sign.html')


@app.route('/status/')
def cassh_status():
    req = LBC.get_ca()
    return render_template('status.html', var=req)

@app.errorhandler(404)
def page_not_found(error):
    return render_template('404.html'), 404

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    app.run(debug=True, host='0.0.0.0', port=port)
