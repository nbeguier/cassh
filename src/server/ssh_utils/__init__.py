#!/usr/bin/env python
"""
ssh_utils lib

Copyright 2017-2022 Nicolas BEGUIER
Licensed under the Apache License, Version 2.0
Written by Nicolas BEGUIER (nicolas_beguier@hotmail.com)

"""

from os import remove
from subprocess import check_output, CalledProcessError

def get_fingerprint(public_key_filename):
    """
    Returns a key fingerprint
    """
    try:
        fingerprint = ' '.join(check_output([
            'ssh-keygen',
            '-l',
            '-E', 'sha512',
            '-f', public_key_filename]).decode('utf-8').split('\n')[0].split()[:2])
    except CalledProcessError:
        fingerprint = 'Unknown'
    return fingerprint

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

class Authority():
    """
    Class which control authority certification
    """
    def __init__(self, ca_key, krl):
        self.ca_key = ca_key
        self.krl = krl

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

    def generate_empty_krl(self):
        """
        Generates an empty KRL file.
        """
        check_output([
            'ssh-keygen',
            '-k',
            '-f', self.krl])

    def update_krl(self, public_key_filename):
        """
        Update KRL by revoking key.
        """
        check_output([
            'ssh-keygen',
            '-k',
            '-f', self.krl,
            '-u',
            '-s', self.ca_key,
            public_key_filename])
