#!/usr/bin/env python
#-*- coding: utf-8 -*-
""" Netbox CLI """

# Standard library imports
from argparse import ArgumentParser
from ConfigParser import ConfigParser, NoOptionError
from json import dumps, loads
from os import getenv
from os.path import isfile
from sys import argv
from time import strftime
# Third party library imports
from requests import Session

# Debug
# from pdb import set_trace as st

def test_result(device, print_error=False):
    """
    Return True is the device is OK.
    """
    try:
        device['results'][0]
    except IndexError:
        if print_error:
            print 'No device found.'
        return False
    except KeyError:
        print 'Connection error. Do you have a valid token ?'
        exit(1)
    return True

def display_device(device, display_model=False):
    """
    Display results.
    """
    print 'Name: %s' % device['display_name']
    print 'ID: %s' % device['id']
    print 'Serial Number: %s' % device['serial']
    print 'Site: %s' % device['site']['name']
    print 'Rack: %s' % device['rack']['name']
    print 'U: %s' % device['position']
    if display_model:
        print 'Model: %s, %s' % (device['device_type']['manufacturer']['name'],\
            device['device_type']['model'])
    return True

def display_devices_type(devices_type):
    """
    Display results.
    """
    for device_type in devices_type['results']:
        print device_type['model']

def read_conf(conf_path):
    """
    Read NetBox configuration file.
    """
    config = ConfigParser()
    config.read(conf_path)
    user_metadata = {}
    try:
        user_metadata['name'] = config.get('user', 'name')
        user_metadata['token'] = config.get('user', 'token')
        user_metadata['url'] = config.get('user', 'url')
    except NoOptionError as error_msg:
        print "Can't read configuration file..."
        print error_msg
        exit(1)
    return user_metadata

def fill_csv(metadata):
    """
    Add new device in a csv file, ready to import
    """
    date = strftime('%Y%m%d')
    csv_filename = 'ready_to_import_' + date + '.csv'

    if isfile(csv_filename):
        write_mode = 'a'
    else:
        write_mode = 'w'

    csv_imput = metadata['serial'] + ',' + metadata['device_role'] + ',,'\
         + metadata['manufacturer'] + ',' + metadata['model'] + ',,' + metadata['serial'] + ',,'\
         + metadata['status'] + ',' + metadata['site'] + ',' + metadata['rack'] + ','\
         + metadata['position'] + ',' + metadata['face']+'\n'

    with open(csv_filename, write_mode) as csv_file:
        csv_file.write(csv_imput)
    print csv_imput


class NetBox(object):
    """
    Main NetBox class.
"""
    def __init__(self, user_metadata):
        """
        Init file.
        """
        self.token = user_metadata['token']
        self.session = Session()
        self.url = user_metadata['url']

    def update_name(self, device_id, update_name, update_name_serial):
        """
        Rename a device.
        """
        headers = {'Authorization': 'Token %s' % self.token}
        # Device exists
        try:
            serial = loads(self.session.get('%s/api/dcim/devices/%s/' % \
                (self.url, device_id), headers=headers).text)['serial']
        except KeyError:
            print "ID=%s doesn't exist or your token is invalid." % device_id
            exit(1)
        if update_name_serial:
            update_name = serial
        payload = {'name': update_name}
        print "Rename ID=%s as '%s'" % (device_id, update_name)
        self.session.patch('%s/api/dcim/devices/%s/' % \
            (self.url, device_id), headers=headers, data=payload)

    def update(self, device_id, update_name=None, update_name_serial=False):
        """
        Update device informations.
        """
        if update_name is not None or update_name_serial:
            self.update_name(device_id, update_name, update_name_serial)
        else:
            exit(1)
        exit(0)

    def search(self, keyword, options):
        """
        Search function.
        """
        headers = {'Authorization': 'Token %s' % self.token}
        query = 'q'
        if options['rack_name'] is not None:
            # Get rack_id
            for rack in loads(self.session.get('%s/api/dcim/racks/'\
                % (self.url), headers=headers).text)['results']:
                if rack['name'] == options['rack_name']:
                    print "Site: %s, Rack: %s" % (rack['site']['name'], rack['name'])
                    print '---------'
                    rack_id = rack['id']
            json_result = loads(self.session.get(\
                '%s/api/dcim/devices/?%s=%s&rack_id=%s' % (self.url, query, keyword, rack_id),\
                headers=headers).text)
        else:
            json_result = loads(self.session.get(\
                '%s/api/dcim/devices/?%s=%s' % (self.url, query, keyword),\
                headers=headers).text)
        if options['raw']:
            print dumps(json_result)
        elif test_result(json_result, print_error=True):
            if options['display_all']:
                for device in json_result['results']:
                    display_device(device, display_model=options['display_model'])
                    print '---------'
            else:
                display_device(json_result['results'][0], display_model=options['display_model'])
        else:
            exit(2)
        exit(0)

    def scanner(self, site, rack):
        """
        Waiting for a serial number from stdin
        """
        headers = {'Authorization': 'Token %s' % self.token}
        query = 'q'
        print "Write 'exit' to quit"
        while True:
            serial = raw_input('Listening for new serial...\n')
            if serial == 'exit':
                exit(0)
            json_result = loads(self.session.get(\
                '%s/api/dcim/devices/?%s=%s' % (self.url, query, serial),\
                headers=headers).text)
            if test_result(json_result):
                print '---------'
                display_device(json_result['results'][0])
                print '---------'
            else:
                choice = raw_input('Would you like to register this new serial (y/N) ?')
                if choice == 'y':
                    """
                    ask node creation related questions (manufacturer, model, etc)
                    """
                    metadata = {}
                    metadata['serial'] = serial
                    metadata['device_role'] = 'Server'
                    metadata['manufacturer'] = raw_input("Which Manufacturer (Ex: 'HP', 'Dell'):  ")
                    print 'Model example:'
                    req = loads(self.session.get('%s/api/dcim/device-types/?q=%s'\
                     % (self.url, metadata['manufacturer']), headers=headers).text)
                    display_devices_type(req)
                    metadata['model'] = raw_input('Which Model:  ')
                    metadata['status'] = 'Active'
                    metadata['site'] = site
                    metadata['rack'] = rack
                    metadata['position'] = raw_input('Which Position (Ex: 42):  ')
                    metadata['face'] = 'front'
                    fill_csv(metadata)
        exit(0)


if __name__ == '__main__':

    CONF_FILE = '%s/.netboxconfig' % getenv('HOME')

    if not isfile(CONF_FILE):
        print 'Config file missing : %s' % CONF_FILE
        print 'Example:'
        print '[user]'
        print 'name = user'
        print 'token = 3d1d538a4efff0f2fcdc617f12728883'
        print 'url = https://netbox.private.net'
        exit(1)

    PARSER = ArgumentParser()

    SUBPARSERS = PARSER.add_subparsers(help='commands')

    # Display Arguments
    UPDATE_PARSER = SUBPARSERS.add_parser('update', help='Update device information')
    UPDATE_PARSER.add_argument('id', action='store', help="Device ID")
    UPDATE_PARSER.add_argument('--name', action='store', help='Set Name')
    UPDATE_PARSER.add_argument('--name-serial', default=False, action='store_true',\
                               help='Set Name like serial')

    # Search Arguments
    SEARCH_PARSER = SUBPARSERS.add_parser('search', help='Search devices')
    SEARCH_PARSER.add_argument('keyword', action='store', help='Keyword of the search')
    SEARCH_PARSER.add_argument('--raw', default=False, action='store_true',
                               help='Raw json result')
    SEARCH_PARSER.add_argument('--display_model', default=False, action='store_true',
                               help='Display server model')
    SEARCH_PARSER.add_argument('--rack', action='store',
                               help='Display rack')
    SEARCH_PARSER.add_argument('--all', default=False, action='store_true',
                               help='Display all devices who match keyword')

    # Scanner Arguments
    SCANNER_PARSER = SUBPARSERS.add_parser('scanner',\
        help='Show informations linked to a serial number when using the scanner scanner')
    SCANNER_PARSER.add_argument('-s', '--site', action='store', help='Site Name')
    SCANNER_PARSER.add_argument('-r', '--rack', action='store', help='Rack Name')

    ARGS = PARSER.parse_args()

    NETBOX = NetBox(read_conf(CONF_FILE))

    if argv[1] == 'update':
        NETBOX.update(ARGS.id, update_name=ARGS.name, update_name_serial=ARGS.name_serial)
    elif argv[1] == 'search':
        OPTS = {}
        OPTS['raw'] = ARGS.raw
        OPTS['display_all'] = ARGS.all
        OPTS['rack_name'] = ARGS.rack
        OPTS['display_model'] = ARGS.display_model
        NETBOX.search(ARGS.keyword, OPTS)
    elif argv[1] == 'scanner':
        if ARGS.site is None or ARGS.rack is None:
            print 'You have to specify your site (%s) and/or your rack (%s).'\
             % (ARGS.site, ARGS.rack)
            exit(1)
        NETBOX.scanner(ARGS.site, ARGS.rack)

    exit(1)
