#!/usr/bin/env python
# -*- coding: utf-8 -*-
# vim: ts=4 sw=4 et
'''
This script is used to provide a yaml config to puppet.
It takes one argument, a hostname, if not it returns an error.
It try to load a default config for our host, then a config based
on the naming charte, and a fqdn specific conf file.
If same classe/parameter are defined in these files, the laste entry is kept.
The script exits with 0 if OK and 1 if not.

Author : Franck CAUVET <fcauvet@e-merchant.com> / f.cauvet@pixmania-group.com
Copyright 2011 E-merchant
All rights reserved.

v 1.4 Last Modified = 2012-03-19
v 1.5 Last Modified = 2012-06-20 by Maxime Guillet: Add LDAP support
v 1.6 Last Modified = 2013-10-22 by Maxime Guillet: Change fonction definition
'''

from yaml import safe_load, safe_dump
import sys
from re import sub
import os.path

#############
# VARIABLES #
#############
# Where to find our yaml file definitions
path_to_yaml_file = os.path.dirname(os.path.realpath(__file__)) + "/../conf/"

# default file to load for each node
default_node = 'default-node.yaml'

# Define our naming policy attributes, these values will be added to node's parameters
# These names MUST match our files under $path_to_yaml_file
# FONCTION.SERVICE.PLATFORM.ENVIRONMENT.SITE.E-MERCHANT.NET
# Exe : web01.front.v2.prod.vit.e-merchant.net
naming_policy = {
    'net':'em-net',
    'domain':'em-domain',
    'site':'site',
    'platform':'platform',
    'environment':'env',
}

###################
# Node definition #
###################
# See puppet required YAML template http://docs.puppetlabs.com/guides/external_nodes.html
# We need a list of class, parameter and a value for environment
parameters = dict()
classes = dict()
environment = None

####################
# LDAP cretentials #
####################
ldap_basedn = 'dc=e-merchant,dc=net'
ldap_binddn = 'cn=puppet,ou=roles,' + ldap_basedn
ldap_bindpw = 'KoNeJPfdY3xcTtsV'
ldap_uri = 'ldap://ldap.e-merchant.net/'

ldap_dev_ou = 'ou=people,' + ldap_basedn
ldap_dev_attrs = ['uid', 'uidNumber', 'gidNumber']
ldap_dev_filter = '(objectClass=posixAccount)'

#############
# Functions #
#############
def add_class(name, param = None):
    '''
    Add class to our node
    Name is required, parameter name and its value are optionnal for parameterized classes
    '''
    if param != None:
        classes[name] = param
    # Else, keep only the classe name
    else:
        classes[name] =  None

def add_parameter(name, value):
    '''
    Add parameter to our node
    The name of the parameter and its value are mandatory
    '''
    parameters[name] = value

def add_env(env):
    '''
    Add Environment to our node
    The env name is required
    '''
    global environment
    environment = env

def split_fqdn(fqdn):
    '''
    Split the host fqdn regards to our naming chart:
    FONCTION.SERVICE.PLATFORM.ENVIRONMENT.SITE.E-MERCHANT.NET
    '''
    # Check our format
    if fqdn.count(".") != 6:
        # Exit if it does not match our naming chart
        print >> sys.stderr, 'Error: Incorrect hostname'
        sys.exit(1)

    # Split our fqdn, we need a global variable to use
    # these informations to load specifics yaml files
    parameter = fqdn.split(".")

    # Keep parameters from FQDN
    # our name must match a fonction
    fonction = parameter[0]
    my_fonction = sub(r'[0-9]+$', '', fonction)
    add_parameter('fonction', my_fonction)
    add_parameter('service', parameter[1])
    add_parameter(naming_policy['platform'], parameter[2])
    add_parameter(naming_policy['environment'], parameter[3])
    add_parameter(naming_policy['site'], parameter[4])
    add_parameter(naming_policy['domain'], parameter[5])
    add_parameter(naming_policy['net'], parameter[6])


# Parse yaml file and fill our classes, parameters dict
def parse_file(yamlfile, section):
    '''
    Parse classes from yaml file
    '''
    try:
        my_dict = ()
        my_dict = yamlfile[section]
        # Define our method regardint our yaml section
        if section == 'classes':
            function = add_class
        elif section == 'parameters':
            function = add_parameter
        else:
            add_env(my_dict)
            return

        # Add each value to our node
        for value in my_dict:
            for specific_list in ['user_list', 'ora_list']:
                if value == specific_list:
                    for user in my_dict[value]:
                        if not my_dict[value][user]:
                            my_dict[value][user] = dict()

                        if userref and specific_list in userref and user in userref[specific_list]:
                            my_dict[value][user].update(userref[specific_list][user])

            function(value, my_dict[value])
    # Catch exception
    except (TypeError, KeyError):
        # If we have an empty classes/parameters section in yaml file
        # Or incorrect value
        # If we have no classes/parameters section in yaml file
        # Do nothing
        pass
    except:
        print >> sys.stderr, 'Error : unexpected error while parsing yaml file'

def load_file(path):
    '''
    Open yaml file
    '''
    try:
        # Open file
        stream = file(path, 'r')
        # Load file
        yamlfile = safe_load(stream)
        # Parse file to load classes from yaml file
        parse_file(yamlfile, 'classes')
        # Parse file to load parameters from yaml file
        parse_file(yamlfile, 'parameters')
        # Parse file to load environment from yaml file
        parse_file(yamlfile, 'environment')
        # Close file
        stream.close()
    except IOError:
        # if file not found
        # Do nothing
        pass
    except:
        # Unexpected error
        # Exit
        print >> sys.stderr, 'Error : Unexpected error wile loading yaml conf file '+path
        print >> sys.stderr, '        Check if there are some tabulations in file'
        sys.exit(1)

def load_reference_file(path):
    '''
    Load users reference file
    '''
    if not os.path.exists(path):
        return False

    try:
        stream = file(path, 'r')
        yamlref = safe_load(stream)
        stream.close()

        new_user_list = dict()
        if 'user_list' in yamlref:
            for application in yamlref['user_list']:

                if not parameters['env'] in yamlref['user_list'][application]:
                    continue

                for suffix in yamlref['user_list'][application][parameters['env']]:
                    if suffix == 'default':
                        user_name = application
                    else:
                        user_name = application + '_' + str(suffix)

                    new_user_list[user_name] = yamlref['user_list'][application][parameters['env']][suffix]

        yamlref['user_list'] = new_user_list

        return yamlref
    except TypeError:
        return False

def load_config(config):
    '''
    Load default node config
    '''
    if config == 'naming_policy':
        # Load puppet conf according to our naming charte, /!\ order matters !
        # Load net conf yaml
        yamlfile = path_to_yaml_file+naming_policy['net']+'/'+parameters[naming_policy['net']]+'.yaml'
        load_file(yamlfile)
        # Load domain conf yaml
        yamlfile = path_to_yaml_file+naming_policy['domain']+'/'+parameters[naming_policy['domain']]+'.yaml'
        load_file(yamlfile)
        # Load site conf yaml
        yamlfile = path_to_yaml_file+naming_policy['site']+'/'+parameters[naming_policy['site']]+'.yaml'
        load_file(yamlfile)
        # Load platform conf yaml
        yamlfile = path_to_yaml_file+naming_policy['platform']+'/'+parameters[naming_policy['platform']]+'.yaml'
        load_file(yamlfile)
        # Load env conf yaml
        yamlfile = path_to_yaml_file+naming_policy['platform']+'/'+parameters[naming_policy['platform']]+'/'+parameters[naming_policy['environment']]+'.yaml'
        load_file(yamlfile)
        # Load fonction-service conf yaml
        yamlfile = path_to_yaml_file+naming_policy['platform']+'/'+parameters[naming_policy['platform']]+'/'+parameters[naming_policy['environment']]+'/'+parameters['fonction']+'-'+parameters['service']+'.yaml'
        load_file(yamlfile)
    if config == fqdn:
        # If we have a file for our host fqdn, load it
        # Load default classe file for minimal set
        yamlfile = path_to_yaml_file+'fqdn/'+fqdn+'.yaml'
        load_file(yamlfile)

########
# Main #
########
# We must provide an argument to this script
if len(sys.argv) != 2:
    print >> sys.stderr, 'Please provide a hostname'
    sys.exit(1)

# Get host FQDN in argument
fqdn = sys.argv[1]

# Split FQDN into several parameters
split_fqdn(fqdn)

# Get user data reference
userref = load_reference_file(os.path.join(path_to_yaml_file, 'resources/resource.yaml'))

# Load config according to our splitted FQDN
load_config('naming_policy')
# Load a specific host config if exists
load_config(fqdn)

# Load user from ldap
if parameters and 'users_by_ldap' in parameters and parameters['env'] == 'dev':
    # try to load LDAP modues
    try:
        import ldap
    except ImportError:
        print >> sys.stderr, 'You must install python-ldap package.'
        sys.exit(1)

    # initialize ldap connection
    ldap_conn = ldap.initialize(ldap_uri)
    ldap_conn.protocol_version = ldap.VERSION3
    ldap_conn.network_timeout = 3
    ldap_conn.timelimit = 3
    try:
        ldap_conn.bind(ldap_binddn, ldap_bindpw)
    except ldap.LDAPError, e:
        print >> sys.stderr, 'Invalid LDAP credentials.'
        sys.exit(1)

    # search users
    try:
        # special search for dev users
        r = ldap_conn.search_s(ldap_dev_ou, ldap.SCOPE_SUBTREE, ldap_dev_filter, ldap_dev_attrs)

    except ldap.LDAPError, e:
        print >> sys.stderr, 'Invalid user search (%s).' % e[0]['desc']
        ldap_conn.unbind()
        sys.exit(1)

    ldap_conn.unbind()

    if r:
        # create user_list parameter
        if not 'user_list' in parameters:
            parameters['user_list'] = dict()

        for user in r:
            user = user[1]

            # create user dict if not exists
            if not user['uid'][0] in parameters['user_list']:
                parameters['user_list'][user['uid'][0]] = dict()

            yaml_user_data = parameters['user_list'][user['uid'][0]]

            # define user data
            user_data = {
                'uid': int(user['uidNumber'][0]),
                'gid': int(user['gidNumber'][0]),
                'template': 'vhost-dev',
                'php_template': 'dev_fpm_pool.conf',
                'php_max_execution_time': '300',
                'php_memory_limit': '64M',
                'idle_timeout': '299',
            }

            # merge ldap data with yaml data
            user_data.update(yaml_user_data)

            # replacing yaml data with the merged one
            parameters['user_list'][user['uid'][0]] = user_data

# Print our node definition into YAML format
node = {'parameters':parameters, 'classes':classes}
print safe_dump(node, default_flow_style = False, explicit_start = True)

# End with status OK for puppet
sys.exit(0)
