#!/usr/bin/env python
""" ssh_utils lib """

from os import remove
from subprocess import check_output

def get_fingerprint(public_key_filename):
    """
    Return Fingerprint
    """
    return check_output([
        'ssh-keygen',
        '-l',
        '-f', public_key_filename,
        '-E', 'md5']).split('\n')[0]

def get_cert_contents(public_key_filename):
    """
    Print cert
    """
    if public_key_filename.endswith('.pub'):
        public_key_filename = public_key_filename[:-4]
    cert_filename = public_key_filename + '-cert.pub'
    with open(cert_filename, 'r') as pub_key:
        cert_contents = pub_key.read()
    remove(cert_filename)
    return cert_contents

class Authority(object):
    """
    Class which control authority certification
    """
    def __init__(self, ca_key):
        self.ca_key = ca_key

    def sign_public_user_key(self, public_key_filename, username, duration, principals):
        """
        Sign public key
        """
        check_output([
            'ssh-keygen',
            '-s', self.ca_key,
            '-I', username,
            '-V', duration,
            '-n', principals,
            public_key_filename])
        return get_cert_contents(public_key_filename)
