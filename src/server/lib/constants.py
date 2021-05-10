#!/usr/bin/env python
"""
Lib/constants

Copyright 2017-2021 Nicolas BEGUIER
Licensed under the Apache License, Version 2.0
Written by Nicolas BEGUIER (nicolas_beguier@hotmail.com)
"""

from re import compile as re_compile, IGNORECASE

STATES = {
    0: 'ACTIVE',
    1: 'REVOKED',
    2: 'PENDING',
    'ACTIVE': 0,
    'REVOKED': 1,
    'PENDING': 2,
}

PATTERN_EXPIRY = re_compile('^([0-9]+)+[dh]$')
PATTERN_PRINCIPALS = re_compile(r'^([a-zA-Z-\d]+)$')
PATTERN_REALNAME = re_compile(
    r"(^[-!#$%&'*+/=?^_`{}|~0-9A-Z]+(\.[-!#$%&'*+/=?^_`{}|~0-9A-Z]+)*"
    r'|^"([\001-\010\013\014\016-\037!#-\[\]-\177]|\\[\001-011\013\014\016-\177])*"'
    r')@(?:[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?\.)+[A-Z]{2,6}\.?$', IGNORECASE)
PATTERN_USERNAME = re_compile("^([a-z]+)$")

URLS = (
    '/admin/([a-z]+)', 'Admin',
    '/admin/([a-z]+)/principals', 'Principals',
    '/admin/all/principals/search', 'PrincipalsSearch',
    '/ca', 'Ca',
    '/client', 'Client',
    '/client/status', 'ClientStatus',
    '/cluster/status', 'ClusterStatus',
    '/health', 'Health',
    '/krl', 'Krl',
    '/ping', 'Ping',
    '/test_auth', 'TestAuth',
)
