#!/usr/bin/python3
#-*- coding: utf-8 -*-
""" cassh_html """

# Standard library imports
from __future__ import print_function
from datetime import datetime
from functools import wraps
from json import decoder, dumps, loads
from os import getenv, path

# Third party library imports
from flask import Flask, render_template, request, Response, redirect, url_for, send_from_directory
from urllib3 import disable_warnings
from requests import get, post
from requests.exceptions import ConnectionError
from werkzeug import secure_filename

# Disable HTTPs warnings
disable_warnings()

# Debug
from pdb import set_trace as st

APP = Flask(__name__)
APP.config.from_pyfile('settings.txt')
# These are the extension that we are accepting to be uploaded
APP.config['ALLOWED_EXTENSIONS'] = set(['pub'])

def allowed_file(filename):
    """ For a given file, return whether it's an allowed type or not """
    return '.' in filename and \
           filename.rsplit('.', 1)[1] in APP.config['ALLOWED_EXTENSIONS']

def check_auth_by_status(auth):
    try:
        req = get(APP.config['CASSH_URL'] + '/client' + 
            auth_url(auth.username, password=auth.password), verify=False)
    except ConnectionError:
        return Response('Connection error : %s' % APP.config['CASSH_URL'])
    try:
        result = loads(req.text)
    except decoder.JSONDecodeError:
        return False
    return True

def authenticate():
    """Sends a 401 response that enables basic auth"""
    return Response(
        'Could not verify your access level for that URL.\n'
        'You have to login with proper credentials', 401,
        {'WWW-Authenticate': 'Basic realm="Login Required"'})

def requires_auth(func):
    """ Wrapper which force authentication """
    @wraps(func)
    def decorated(*args, **kwargs):
        """ Authentication wrapper """
        auth = request.authorization
        current_user = {}
        if not auth or not check_auth_by_status(auth):
            return authenticate()
        current_user['name'] = auth.username
        current_user['password'] = auth.password
        current_user['is_authenticated'] = True
        return func(*args, **kwargs, current_user=current_user)
    return decorated

def auth_url(realname, password=None, prefix=None):
    """
    Return a ?xxx=xxx to put at the end of a GET request.
    """
    if APP.config['ENABLE_LDAP']:
        if prefix is None:
            return '?realname=%s&password=%s'\
                % (realname, password)
        else:
            return prefix + '&realname=%s&password=%s'\
                % (realname, password)
    else:
        if prefix is None:
            return ''
        else:
            return prefix


@APP.route('/')
@requires_auth
def index(current_user=None):
    """ Display home page """
    return render_template('homepage.html', username=current_user['name'])

@APP.route('/add/')
@requires_auth
def cassh_add(current_user=None):
    """ Display add key page """
    return render_template('add.html', username=current_user['name'], result=None)

@APP.route('/sign/')
@requires_auth
def cassh_sign(current_user=None):
    """ Display sign page """
    return render_template('sign.html', username=current_user['name'])

@APP.route('/status/')
@requires_auth
def cassh_status(current_user=None):
    """ Display status page """
    try:
        req = get(APP.config['CASSH_URL'] + '/client' + 
            auth_url(current_user['name'], password=current_user['password']), verify=False)
    except ConnectionError:
        return Response('Connection error : %s' % APP.config['CASSH_URL'])
    try:
        result = loads(req.text)
        is_expired = datetime.strptime(result['expiration'], '%Y-%m-%d %H:%M:%S') < datetime.now()
        if result['status'] == 'ACTIVE':
            if is_expired:
                result['status'] = 'EXPIRED'
            else:
                result['status'] = 'SIGNED'
    except decoder.JSONDecodeError:
        result = req.text

    return render_template('status.html', username=current_user['name'], result=result)

# Route that will process the file upload
@APP.route('/sign/upload', methods=['POST'])
@requires_auth
def upload(current_user=None):
    pubkey = request.files['file']
    try:
        req = post(APP.config['CASSH_URL'] + '/client' +
            auth_url(current_user['name'], password=current_user['password']), \
            data=pubkey, verify=False)
    except ConnectionError:
        return Response('Connection error : %s' % APP.config['CASSH_URL'])
    if 'Error' in req.text:
        return Response(req.text)

    with open(path.join(APP.config['UPLOAD_FOLDER'], current_user['name']), 'w') as f:
        f.write(req.text)

    return send_from_directory(APP.config['UPLOAD_FOLDER'], current_user['name'])


@APP.errorhandler(404)
def page_not_found(_):
    """ Display error page """
    return render_template('404.html'), 404

if __name__ == '__main__':
    PORT = int(getenv('PORT', 5000))
    APP.run(debug=True, host='0.0.0.0', port=PORT)
